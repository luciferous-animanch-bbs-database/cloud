resource "aws_cognito_identity_pool" "web" {
  identity_pool_name               = "web_auth"
  allow_unauthenticated_identities = true
}

resource "aws_cognito_identity_pool_roles_attachment" "web" {
  identity_pool_id = aws_cognito_identity_pool.web.id
  roles = {
    unauthenticated = aws_iam_role.cognito_unauth.arn
  }
}