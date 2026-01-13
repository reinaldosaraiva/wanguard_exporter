// Package logging provides a wrapper for slog that supports Printf-style formatting
package logging

import (
	"fmt"
	"log/slog"
	"os"
)

var (
	// Default logger instance
	logger *slog.Logger
)

// Init initializes the global logger
func Init(level string, format string) {
	var slogLevel slog.Level
	switch level {
	case "debug":
		slogLevel = slog.LevelDebug
	case "info":
		slogLevel = slog.LevelInfo
	case "warn":
		slogLevel = slog.LevelWarn
	case "error":
		slogLevel = slog.LevelError
	default:
		slogLevel = slog.LevelInfo
	}

	var handler slog.Handler
	if format == "json" {
		handler = slog.NewJSONHandler(os.Stdout, &slog.HandlerOptions{
			Level: slogLevel,
		})
	} else {
		handler = slog.NewTextHandler(os.Stdout, &slog.HandlerOptions{
			Level: slogLevel,
		})
	}

	logger = slog.New(handler)
	slog.SetDefault(logger)
}

// GetLogger returns the current logger instance
func GetLogger() *slog.Logger {
	if logger == nil {
		logger = slog.New(slog.NewTextHandler(os.Stdout, &slog.HandlerOptions{
			Level: slog.LevelInfo,
		}))
	}
	return logger
}

// Printf-style logging functions for backward compatibility

// Info logs a formatted info message
func Info(format string, args ...interface{}) {
	GetLogger().Info(fmt.Sprintf(format, args...))
}

// Error logs a formatted error message
func Error(format string, args ...interface{}) {
	GetLogger().Error(fmt.Sprintf(format, args...))
}

// Warn logs a formatted warning message
func Warn(format string, args ...interface{}) {
	GetLogger().Warn(fmt.Sprintf(format, args...))
}

// Debug logs a formatted debug message
func Debug(format string, args ...interface{}) {
	GetLogger().Debug(fmt.Sprintf(format, args...))
}

// Fatal logs a formatted fatal message and exits
func Fatal(format string, args ...interface{}) {
	GetLogger().Error(fmt.Sprintf(format, args...))
	os.Exit(1)
}

// Fatalf is an alias for Fatal
func Fatalf(format string, args ...interface{}) {
	Fatal(format, args...)
}
