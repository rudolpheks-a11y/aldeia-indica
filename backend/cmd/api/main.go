package main

import (
	"context"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/rudolpheks-a11y/aldeia-indica/backend/internal/auth"
	"github.com/rudolpheks-a11y/aldeia-indica/backend/internal/config"
	"github.com/rudolpheks-a11y/aldeia-indica/backend/internal/email"
	"github.com/rudolpheks-a11y/aldeia-indica/backend/internal/fcm"
	"github.com/rudolpheks-a11y/aldeia-indica/backend/internal/handler"
	"github.com/rudolpheks-a11y/aldeia-indica/backend/internal/platform/logger"
	"github.com/rudolpheks-a11y/aldeia-indica/backend/internal/platform/postgres"
	"github.com/rudolpheks-a11y/aldeia-indica/backend/internal/server"
	"github.com/rudolpheks-a11y/aldeia-indica/backend/internal/service"
	"github.com/rudolpheks-a11y/aldeia-indica/backend/internal/storage"
	"github.com/rudolpheks-a11y/aldeia-indica/backend/internal/ws"
)

func main() {
	cfg := config.Load()
	log := logger.New(cfg.LogLevel)

	ctx := context.Background()

	db, err := postgres.Connect(ctx, cfg.DatabaseURL)
	if err != nil {
		log.Error("connect to database", "error", err)
		os.Exit(1)
	}
	defer db.Close()
	log.Info("database connected")

	s3Client, err := storage.NewS3Client(ctx, cfg)
	if err != nil {
		log.Error("init s3 client", "error", err)
		os.Exit(1)
	}

	fcmClient, err := fcm.New(ctx, cfg.FCMServiceAccount, log)
	if err != nil {
		log.Error("init fcm client", "error", err)
		os.Exit(1)
	}

	j := auth.NewJWT(cfg.JWTSecret, cfg.JWTAccessExpiry, cfg.JWTRefreshExpiry)

	emailClient := email.New(cfg.ResendAPIKey, cfg.FromEmail, log)

	authSvc := service.NewAuthService(db, j, cfg.JWTRefreshExpiry, emailClient)
	userSvc := service.NewUserService(db)
	providerSvc := service.NewProviderService(db, log)
	notifSvc := service.NewNotificationService(db)
	ratingSvc := service.NewRatingService(db, providerSvc, notifSvc)
	recSvc := service.NewRecommendationService(db, providerSvc, notifSvc)
	chatSvc := service.NewChatService(db)
	analyticsSvc := service.NewAnalyticsService(db)
	bulletinSvc := service.NewBulletinService(db)

	hub := ws.NewHub()

	authH := handler.NewAuthHandler(authSvc)
	approvalH := handler.NewApprovalHandler(userSvc)
	providerH := handler.NewProviderHandler(providerSvc, analyticsSvc)
	ratingH := handler.NewRatingHandler(ratingSvc)
	recH := handler.NewRecommendationHandler(recSvc)
	requestH := handler.NewRequestHandler(db, notifSvc)
	uploadH := handler.NewUploadHandler(s3Client)
	adminH := handler.NewAdminHandler(db)
	categoryH := handler.NewCategoryHandler(db)
	chatH := handler.NewChatHandler(chatSvc, analyticsSvc)
	bulletinH := handler.NewBulletinHandler(bulletinSvc)
	notifH := handler.NewNotificationHandler(notifSvc)
	wsH := ws.NewHandler(hub, chatSvc, fcmClient, j, log)

	router := server.NewRouter(
		log, j,
		authH, providerH, ratingH, recH,
		approvalH, requestH, uploadH, adminH, categoryH,
		chatH, bulletinH, notifH, wsH,
	)

	srv := server.New(cfg.Port, router)

	go func() {
		if err := srv.Start(); err != nil && err != http.ErrServerClosed {
			log.Error("server error", "error", err)
			os.Exit(1)
		}
	}()

	quit := make(chan os.Signal, 1)
	signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
	<-quit

	log.Info("shutting down server")
	shutdownCtx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	if err := srv.Shutdown(shutdownCtx); err != nil {
		log.Error("shutdown error", "error", err)
	}
	log.Info("server stopped")
}
