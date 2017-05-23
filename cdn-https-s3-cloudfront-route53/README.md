# cdn-https-s3-cloudfront-route53

HTTPS CDN example using:

* AWS S3 as origin
* AWS CloudFront as CDN
* AWS Route53 as DNS
* AWS Certificate Manager as HTTPS certificate manager

# Prerequisites

It is assumed that you run it in your AWS test account. User invoking `deploy.sh` should have access to: S3, CloudFront, Route53, Certificate Manager. For hosting production application you should use production AWS account with a fine-grained IAM permissions for testing are you good with full permissions to mentioned services.

There are 2 prerequisites which are not part of this script:

1. Domain for DNS_ZONE_NAME already setup in AWS Route53.
2. HTTPS certificate for `cdn.DNS_ZONE_NAME` already in AWS CM. You are fine with a wildcard certificate like `*.DNS_ZONE_NAME` too.

# How does it work?

Assuming `deploy.sh` is configured as:

```
BUCKET_NAME=my-cool-cdn
DNS_ZONE_NAME=my-cool-website.com
```

it will setup a HTTPS CDN with the following configuration:

1. S3 for CDN: my-cool-cdn
2. S3 for CDN logs: my-cool-cdn-logs
3. DNS for CDN: cdn.my-cool-website.com
4. HTTPS for CD: https://cdn.my-cool-website.com

Notice: it may take some time for AWS to fully propagate your changes. For example you may end-up with having 307 temporary redirects for https://cdn.my-cool-website.com/index.html for a couple of hours. If you are getting 307 with cache hit you may also trigger CloudFront invalidations to make sure edge locations refresh their cache. Be patient.
