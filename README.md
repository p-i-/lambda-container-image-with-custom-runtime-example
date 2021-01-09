# Lambda Container Image Support (with Custom Runtime)

This is a brief example how to define a Lambda function with bash using Amazon Linux 2 based Custom Runtime and Container Image Support ([relesed in re:Invent 2020](https://aws.amazon.com/blogs/aws/new-for-aws-lambda-container-image-support/)).

See the blog post for more information:
[aripalo.com/blog/2020/aws-lambda-container-image-support/](https://aripalo.com/blog/2020/aws-lambda-container-image-support/)


## `pipeline.sh` (created by pi@pipad.org 9 Jan 2021)
I have implemented the instructions in bash.
This makes it much easier to see the process flow.
Also it may serve as a decent foundation for a more advanced pipeline (it implements a rudimentary local/staging/production)

### Setup
Modify the ENV-vars in `pipeline.sh`

### Build Image (and test against local)
```
pipeline.sh build staging
```
- Builds build local docker image.
- Tests the container image by spinning up an instance, sending a CURL request, then destroying the instance.

You can CTRL+c at the prompt and `docker exec -it ${container_id} /bin/sh` to get into the box if you like.

### Deploy to AWS (and test against remote)
```
pipeline.sh deploy staging
```
- Creates a repo if it doesn't exist
- Logs into AWS ECR Docker repository
- Tags Docker Image (specific format, so AWS Lambda can find it)
- Pushes image to remote
- Tests
    - If there is a running lambda function with this name, delete it.
    - Create lambda function
    - test against endpoint, printing response

## Usage (Original document)

(Very briefly, again see the blog post for more.)

### Local testing

```sh
cd src

docker build -t lambda-container-demo .
docker run -p 9000:8080 lambda-container-demo:latest
```

In another terminal call:
```sh
curl -XPOST \
"http://localhost:9000/2015-03-31/functions/function/invocations" \
-d 'Hello from Container Lambda!'
```

### Deployment

```sh
cd src

# Build the image
docker build -t lambda-container-demo .

# Create repository
aws ecr create-repository --repository-name lambda-container-demo --image-scanning-configuration scanOnPush=true

# Tag it
docker tag lambda-container-demo:latest 123412341234.dkr.ecr.eu-west-1.amazonaws.com/lambda-container-demo:latest

# Login
aws --region eu-west-1 ecr get-login-password | docker login --username AWS --password-stdin 123412341234.dkr.ecr.eu-west-1.amazonaws.com

# Push the image
docker push 123412341234.dkr.ecr.eu-west-1.amazonaws.com/lambda-container-demo:latest
```

Then either [manually create the Lambda function](https://aripalo.com/blog/2020/aws-lambda-container-image-support/#publish%2C-part-2%3A-lambda) or use the _fresh from the oven_ [CDK deployment](https://github.com/aws/aws-cdk/pull/11809).
