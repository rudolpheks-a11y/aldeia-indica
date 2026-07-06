package storage

import (
	"context"
	"fmt"
	"time"

	"github.com/aws/aws-sdk-go-v2/aws"
	awsconfig "github.com/aws/aws-sdk-go-v2/config"
	"github.com/aws/aws-sdk-go-v2/credentials"
	"github.com/aws/aws-sdk-go-v2/service/s3"
	"github.com/rudolpheks-a11y/aldeia-indica/backend/internal/config"
)

type S3Client struct {
	presign       *s3.PresignClient
	publicBucket  string
	privateBucket string
	baseURL       string
}

func NewS3Client(ctx context.Context, cfg *config.Config) (*S3Client, error) {
	opts := []func(*awsconfig.LoadOptions) error{
		awsconfig.WithRegion(cfg.AWSRegion),
		awsconfig.WithCredentialsProvider(credentials.NewStaticCredentialsProvider(
			cfg.AWSAccessKeyID, cfg.AWSSecretAccessKey, "",
		)),
	}

	if cfg.AWSEndpoint != "" {
		customResolver := aws.EndpointResolverWithOptionsFunc(
			func(service, region string, options ...interface{}) (aws.Endpoint, error) {
				return aws.Endpoint{URL: cfg.AWSEndpoint, HostnameImmutable: true}, nil
			},
		)
		opts = append(opts, awsconfig.WithEndpointResolverWithOptions(customResolver))
	}

	awsCfg, err := awsconfig.LoadDefaultConfig(ctx, opts...)
	if err != nil {
		return nil, fmt.Errorf("load aws config: %w", err)
	}

	client := s3.NewFromConfig(awsCfg, func(o *s3.Options) {
		if cfg.AWSEndpoint != "" {
			o.UsePathStyle = true
		}
	})

	return &S3Client{
		presign:       s3.NewPresignClient(client),
		publicBucket:  cfg.AWSBucketPublic,
		privateBucket: cfg.AWSBucketPrivate,
		baseURL:       cfg.CloudFrontBaseURL,
	}, nil
}

type PresignResult struct {
	UploadURL string `json:"upload_url"`
	ObjectKey string `json:"object_key"`
	ExpiresIn int    `json:"expires_in"`
}

func (c *S3Client) PresignPut(ctx context.Context, objectKey string, isPrivate bool) (*PresignResult, error) {
	bucket := c.publicBucket
	if isPrivate {
		bucket = c.privateBucket
	}

	req, err := c.presign.PresignPutObject(ctx, &s3.PutObjectInput{
		Bucket: aws.String(bucket),
		Key:    aws.String(objectKey),
	}, s3.WithPresignExpires(15*time.Minute))
	if err != nil {
		return nil, fmt.Errorf("presign put: %w", err)
	}

	return &PresignResult{
		UploadURL: req.URL,
		ObjectKey: objectKey,
		ExpiresIn: 900,
	}, nil
}
