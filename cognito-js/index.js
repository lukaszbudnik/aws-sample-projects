
// http://docs.aws.amazon.com/cognito/latest/developerguide/using-amazon-cognito-user-identity-pools-javascript-examples.html

var AWS = require('aws-sdk');
var jwtDecode = require('jwt-decode');
var AmazonCognitoIdentity = require('amazon-cognito-identity-js');
const config = require('./config/config.json');

AWS.config.region = 'us-east-1';

// after first run the temporary password is overwritten with new password
// config.user.temporaryPassword = config.user.newPassword;

var authenticationData = {
    Username : config.user.username,
    Password: config.user.temporaryPassword
};

var authenticationDetails = new AmazonCognitoIdentity.AuthenticationDetails(authenticationData);
var poolData = {
    UserPoolId : config.userPool.id,
    ClientId : config.userPool.clientId
};
var userPool = new AmazonCognitoIdentity.CognitoUserPool(poolData);
var userData = {
    Username : config.user.username,
    Pool : userPool
};
var cognitoUser = new AmazonCognitoIdentity.CognitoUser(userData);

cognitoUser.authenticateUser(authenticationDetails, {

    onSuccess: function (result) {

      var cognitoUser = userPool.getCurrentUser();
          if(cognitoUser != null){
              cognitoUser.getSession(function(err, session) {
                  if (err) {
                      console.error(err);
                      return;
                  }
                  console.log('session validity: ' + session.isValid());

                  var sessionIdInfo = jwtDecode(session.getIdToken().jwtToken);
                  console.log(sessionIdInfo['cognito:groups']);
                  console.log(sessionIdInfo['cognito:roles']);
                  console.log(sessionIdInfo['cognito:preferred_role']);
              });
          }

        console.log('access token = ' + result.getAccessToken().getJwtToken());

        // config.identityPool.authenticatedRoleArn
        var params = {
            IdentityPoolId : config.identityPool.id,
            RoleArn: 'arn:aws:iam::XXX:role/DynamoDBMovies',
            Logins : {
            }
        };
        var login = 'cognito-idp.' + AWS.config.region + '.amazonaws.com/' + config.userPool.id;
        params.Logins[login] = result.getIdToken().getJwtToken();
        AWS.config.credentials = new AWS.CognitoIdentityCredentials(params);

        AWS.config.credentials.get(function(){

          // var s3 = new AWS.S3();
          // var putParams = {
          //   Bucket: config.bucket,
          //   Key: AWS.config.credentials.identityId + '/qwq.txt',
          //   Body: 'test'
          // };
          // s3.putObject(putParams, function (err, data) {
          //   if (err) console.error(err);
          //   else     console.log(data);
          // });
          // var listParams = {
          //   Bucket: config.bucket,
          //   Prefix: AWS.config.credentials.identityId,
          // };
          // s3.listObjectsV2(listParams, function(err, data) {
          //   if (err) console.error(err);
          //   else     console.log(data);
          // });

          var docClient = new AWS.DynamoDB.DocumentClient();

          var table = "Movies";
          var year = 2015;
          var title = "The Big New Movie";
          var params = {
              TableName:table,
              Item:{
                  "year": year,
                  "title": title,
                  "info":{
                      "plot": "Nothing happens at all.",
                      "rating": 0
                  }
              }
          };
          console.log("Adding a new item...");
          docClient.put(params, function(err, data) {
            if (err) {
                console.error("Unable to add item. Error JSON:", JSON.stringify(err, null, 2));
            } else {
                console.log("Added item:", JSON.stringify(data, null, 2));
            }
          });

        });

    },

    onFailure: function(err) {
        console.error(err);
    },

    newPasswordRequired: function(userAttributes, requiredAttributes) {
        // User was signed up by an admin and must provide new
        // password and required attributes, if any, to complete
        // authentication.

        // the api doesn't accept this field back
        delete userAttributes.email_verified;
        delete userAttributes.phone_number_verified;

        cognitoUser.completeNewPasswordChallenge(config.user.newPassword, userAttributes, this);
    }

});
