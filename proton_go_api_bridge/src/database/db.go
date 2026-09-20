package database

import (
	"fmt"
	"log/slog"
	"os"
	"path/filepath"
	"proton_go_api_bridge/native/database/migrations"

	"gorm.io/driver/sqlite"
	"gorm.io/gorm"
)

var Instance *gorm.DB
var DatabaseError error = fmt.Errorf("database not initialized")
var basePathCache string

func SetupDB(basePath string) {
	basePathCache = basePath
	slog.Info("initializing database", slog.String("basePath", basePath))
	DatabaseError = nil

	dbPath := fmt.Sprintf("%s?_foreign_keys=true&_journal_mode=WAL", basePath)
	slog.Debug("database path", slog.String("path", dbPath))

	db, err := gorm.Open(sqlite.Open(dbPath), &gorm.Config{
		DisableForeignKeyConstraintWhenMigrating: true,
	})
	if err != nil {
		slog.Error("initialize database", slog.Any("error", err))
		DatabaseError = err
		return
	}

	slog.Debug("automigrating database")
	err = migrations.ExecuteMigrations(db)
	if err != nil {
		slog.Error("execute migrations", slog.Any("error", err))
		DatabaseError = err
		return
	}

	slog.Info("database initialized")
	Instance = db
}

func Reset() {
	slog.Info("resetting database")
	Teardown()
	SetupDB(basePathCache)
}

func Teardown() {
	db, err := Instance.DB()
	if err != nil {
		slog.Error("get sql.DB from gorm.DB", slog.Any("error", err))
		return
	}
	if err := db.Close(); err != nil {
		slog.Error("close database", slog.Any("error", err))
		DatabaseError = err
		return
	}
	slog.Debug("database closed")

	dbPath := filepath.Join(basePathCache, "contact_bridge.db")
	if err = os.Remove(dbPath); err != nil && !os.IsNotExist(err) {
		slog.Error("delete database", slog.Any("error", err))
		DatabaseError = err
		return
	}
	slog.Info("deleted database", slog.String("path", dbPath))

	_ = os.Remove(dbPath + "-shm")
	_ = os.Remove(dbPath + "-wal")
	_ = os.Remove(dbPath + "-journal")

	Instance = nil
	DatabaseError = fmt.Errorf("database not initialized")
}
