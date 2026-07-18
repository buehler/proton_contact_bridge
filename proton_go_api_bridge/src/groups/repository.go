package groups

import (
	"context"
	"log/slog"
	"proton_go_api_bridge/native/database"
	"proton_go_api_bridge/native/database/models"

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

func (r *GroupRepository) GetAll(_ context.Context) ([]models.Group, error) {
	slog.Debug("fetch all groups")
	var groups []models.Group
	result := r.db.Table("groups").Select("grp as name").Find(&groups)
	if result.Error != nil {
		return nil, result.Error
	}

	return groups, nil
}

func (r *GroupRepository) GetGroupContacts(_ context.Context, groupName string) ([]models.Contact, error) {
	slog.Debug("fetch contacts for group", slog.String("group_name", groupName))
	var contacts []models.Contact
	result := r.db.Table("contacts").
		Select("contacts.*").
		Joins("inner join contact_groups g on g.contact_id = contacts.id").
		Where("g.grp = ?", groupName).
		Find(&contacts)
	if result.Error != nil {
		return nil, result.Error
	}
	return contacts, nil
}
