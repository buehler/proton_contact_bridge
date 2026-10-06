package groups

import (
	"context"
	"log/slog"
	"proton_go_api_bridge/native/database"
	"proton_go_api_bridge/native/database/models"
	"proton_go_api_bridge/native/utils"
	"slices"
	"strings"

	"gorm.io/gorm"
)

type GroupRepository struct {
	db *gorm.DB
}

func NewGroupRepository() *GroupRepository {
	return &GroupRepository{
		db: database.Instance,
	}
}

func (r *GroupRepository) GetAll(ctx context.Context) ([]models.Group, error) {
	slog.DebugContext(ctx, "fetch all groups")
	var rows []struct{ Name string }
	if err := r.db.WithContext(ctx).Table("groups").Select("grp as name").Find(&rows).Error; err != nil {
		return nil, err
	}

	names := make([]string, 0, len(rows))
	for _, row := range rows {
		names = append(names, row.Name)
	}
	names = normalizeGroupNames(names)
	slices.Sort(names)

	groups := utils.MapSlice(names, func(n string) models.Group {
		return models.Group{Name: n}
	})

	return groups, nil
}

func (r *GroupRepository) GetGroupContacts(ctx context.Context, groupName string) ([]models.Contact, error) {
	groupName = strings.TrimSpace(groupName)
	slog.DebugContext(ctx, "fetch contacts for group", slog.String("group_name", groupName))
	if groupName == "" {
		return nil, nil
	}

	var memberships []struct {
		ContactID string
		GroupName string `gorm:"column:grp"`
	}
	if err := r.db.WithContext(ctx).Table("contact_groups").Select("contact_id, grp").Find(&memberships).Error; err != nil {
		return nil, err
	}

	ids := make(map[string]struct{})
	for _, membership := range memberships {
		if strings.TrimSpace(membership.GroupName) == groupName {
			ids[membership.ContactID] = struct{}{}
		}
	}
	if len(ids) == 0 {
		return nil, nil
	}

	contactIDs := make([]string, 0, len(ids))
	for id := range ids {
		contactIDs = append(contactIDs, id)
	}
	slices.Sort(contactIDs)

	var contacts []models.Contact
	if err := r.db.WithContext(ctx).Where("id IN ?", contactIDs).Order("id").Find(&contacts).Error; err != nil {
		return nil, err
	}
	return contacts, nil
}
