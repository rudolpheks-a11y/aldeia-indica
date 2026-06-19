package config

import (
	"os"
	"time"
)

type Config struct {
	Port               string
	DatabaseURL        string
	LogLevel           string
	JWTSecret          string
	JWTAccessExpiry    time.Duration
	JWTRefreshExpiry   time.Duration
	AWSRegion          string
	AWSAccessKeyID     string
	AWSSecretAccessKey string
	AWSBucketPublic    string
	AWSBucketPrivate   string
	AWSEndpoint        string
	CloudFrontBaseURL  string
	FCMServiceAccount  string
}

func Load() *Config {
	accessExpiry, _ := time.ParseDuration(getEnv("JWT_ACCESS_EXPIRY", "15m"))
	refreshExpiry, _ := time.ParseDuration(getEnv("JWT_REFRESH_EXPIRY", "720h"))

	return &Config{
		Port:               getEnv("PORT", "8080"),
		DatabaseURL:        mustEnv("DATABASE_URL"),
		LogLevel:           getEnv("LOG_LEVEL", "info"),
		JWTSecret:          mustEnv("JWT_SECRET"),
		JWTAccessExpiry:    accessExpiry,
		JWTRefreshExpiry:   refreshExpiry,
		AWSRegion:          getEnv("AWS_REGION", "us-east-1"),
		AWSAccessKeyID:     getEnv("AWS_ACCESS_KEY_ID", ""),
		AWSSecretAccessKey: getEnv("AWS_SECRET_ACCESS_KEY", ""),
		AWSBucketPublic:    getEnv("AWS_BUCKET_PUBLIC", "aldeia-public"),
		AWSBucketPrivate:   getEnv("AWS_BUCKET_PRIVATE", "aldeia-private"),
		AWSEndpoint:        getEnv("AWS_ENDPOINT", ""),
		CloudFrontBaseURL:  getEnv("CLOUDFRONT_BASE_URL", ""),
		FCMServiceAccount:  getEnv("FCM_SERVICE_ACCOUNT_JSON", ""),
	}
}

func getEnv(key, fallback string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return fallback
}

func mustEnv(key string) string {
	v := os.Getenv(key)
	if v == "" {
		panic("required environment variable not set: " + key)
	}
	return v
}
