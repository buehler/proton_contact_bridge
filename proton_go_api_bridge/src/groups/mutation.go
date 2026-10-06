package groups

import (
	"context"
	"fmt"
	"log/slog"
	"slices"
	"strings"

	"proton_go_api_bridge/native/contacts"
)

type ContactGroupPatch struct {
	ContactID    string
	AddGroups    []string
	RemoveGroups []string
}

type ContactFailure struct {
	ContactID string
	Message   string
}

type MutationResult struct {
	ChangedContactIDs   []string
	UnchangedContactIDs []string
	FailedContacts      []ContactFailure
	RequestedCount      int
	CompletedCount      int
	SourceName          *string
	TargetName          *string
}

func normalizeGroupNames(names []string) []string {
	seen := make(map[string]struct{}, len(names))
	result := make([]string, 0, len(names))
	for _, raw := range names {
		name := strings.TrimSpace(raw)
		if name == "" {
			continue
		}
		if _, exists := seen[name]; exists {
			continue
		}
		seen[name] = struct{}{}
		result = append(result, name)
	}
	return result
}

func validateGroupName(name string) (string, error) {
	name = strings.TrimSpace(name)
	if name == "" {
		return "", fmt.Errorf("group name is blank")
	}
	if strings.Contains(name, ",") {
		return "", fmt.Errorf("group name contains a comma")
	}
	return name, nil
}

func validateGroupNames(names []string) ([]string, error) {
	validated := make([]string, 0, len(names))
	for _, name := range names {
		var err error
		name, err = validateGroupName(name)
		if err != nil {
			return nil, err
		}
		validated = append(validated, name)
	}
	return normalizeGroupNames(validated), nil
}

func (r *GroupRepository) Rename(ctx context.Context, sourceName, targetName string) (*MutationResult, error) {
	var err error
	sourceName, err = validateGroupName(sourceName)
	if err != nil {
		return nil, err
	}
	targetName, err = validateGroupName(targetName)
	if err != nil {
		return nil, err
	}
	if sourceName == targetName {
		return nil, fmt.Errorf("source and target group names are the same")
	}

	return r.mutateGroup(ctx, sourceName, &targetName, func(current []string) []string {
		for i, name := range current {
			if name == sourceName {
				current[i] = targetName
			}
		}
		return normalizeGroupNames(current)
	})
}

func (r *GroupRepository) Delete(ctx context.Context, name string) (*MutationResult, error) {
	name, err := validateGroupName(name)
	if err != nil {
		return nil, err
	}

	return r.mutateGroup(ctx, name, nil, func(current []string) []string {
		return slices.DeleteFunc(current, func(group string) bool {
			return group == name
		})
	})
}

func (r *GroupRepository) mutateGroup(ctx context.Context, sourceName string, targetName *string, mutate func([]string) []string) (*MutationResult, error) {
	result := &MutationResult{SourceName: &sourceName, TargetName: targetName}
	contacts.ContactWriteMu.Lock()
	defer contacts.ContactWriteMu.Unlock()

	members, err := r.GetGroupContacts(ctx, sourceName)
	if err != nil {
		return nil, err
	}
	result.RequestedCount = len(members)

	contactRepo := contacts.NewContactRepository()
	for _, member := range members {
		result.applyContact(ctx, contactRepo, member.ID, func(categories []string) []string {
			return mutate(normalizeGroupNames(categories))
		})
	}
	return result, nil
}

func (r *GroupRepository) ApplyContactGroupChanges(ctx context.Context, patches []ContactGroupPatch) (*MutationResult, error) {
	normalized := make([]ContactGroupPatch, 0, len(patches))
	seenIDs := make(map[string]struct{}, len(patches))
	for _, patch := range patches {
		patch.ContactID = strings.TrimSpace(patch.ContactID)
		if patch.ContactID == "" {
			return nil, fmt.Errorf("contact ID is blank")
		}
		if _, exists := seenIDs[patch.ContactID]; exists {
			return nil, fmt.Errorf("duplicate contact patch for %s", patch.ContactID)
		}
		seenIDs[patch.ContactID] = struct{}{}

		var err error
		patch.AddGroups, err = validateGroupNames(patch.AddGroups)
		if err != nil {
			return nil, fmt.Errorf("contact %s add groups: %w", patch.ContactID, err)
		}
		patch.RemoveGroups, err = validateGroupNames(patch.RemoveGroups)
		if err != nil {
			return nil, fmt.Errorf("contact %s remove groups: %w", patch.ContactID, err)
		}
		for _, add := range patch.AddGroups {
			if slices.Contains(patch.RemoveGroups, add) {
				return nil, fmt.Errorf("contact %s both adds and removes group %s", patch.ContactID, add)
			}
		}
		normalized = append(normalized, patch)
	}

	result := &MutationResult{RequestedCount: len(normalized)}
	contacts.ContactWriteMu.Lock()
	defer contacts.ContactWriteMu.Unlock()

	contactRepo := contacts.NewContactRepository()
	for _, patch := range normalized {
		remove := make(map[string]struct{}, len(patch.RemoveGroups))
		for _, name := range patch.RemoveGroups {
			remove[name] = struct{}{}
		}
		result.applyContact(ctx, contactRepo, patch.ContactID, func(categories []string) []string {
			next := make([]string, 0, len(categories)+len(patch.AddGroups))
			for _, name := range normalizeGroupNames(categories) {
				if _, removed := remove[name]; !removed {
					next = append(next, name)
				}
			}
			return normalizeGroupNames(append(next, patch.AddGroups...))
		})
	}
	return result, nil
}

func (result *MutationResult) applyContact(ctx context.Context, repo *contacts.ContactRepository, contactID string, mutate func([]string) []string) {
	changed, err := repo.UpdateCategories(ctx, contactID, mutate)
	if err != nil {
		slog.ErrorContext(ctx, "failed to update contact groups", slog.String("contact_id", contactID), slog.Any("error", err))
		result.FailedContacts = append(result.FailedContacts, ContactFailure{ContactID: contactID, Message: err.Error()})
		return
	}
	if changed {
		result.ChangedContactIDs = append(result.ChangedContactIDs, contactID)
	} else {
		result.UnchangedContactIDs = append(result.UnchangedContactIDs, contactID)
	}
	result.CompletedCount++
}
