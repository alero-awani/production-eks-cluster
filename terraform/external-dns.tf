data "tls_certificate" "eks" {
  url = aws_eks_cluster.eks.identity.0.oidc.0.issuer
}

#OIDC Provider
resource "aws_iam_openid_connect_provider" "eks" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.eks.certificates[0].sha1_fingerprint]
  url             = aws_eks_cluster.eks.identity[0].oidc[0].issuer
}

# IAM Role with trust policy
resource "aws_iam_role" "external_dns" {
  name = "external-dns-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRoleWithWebIdentity"
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.eks.arn
        }
        Condition = {
          StringEquals = {
            "${replace(aws_iam_openid_connect_provider.eks.url, "https://", "")}:sub" : "system:serviceaccount:kube-system:external-dns"
            "${replace(aws_iam_openid_connect_provider.eks.url, "https://", "")}:aud" : "sts.amazonaws.com"
          }
        }
      }
    ]
  })
}

data "aws_route53_zone" "zone_selected" {
  zone_id = var.zone_id
}

resource "aws_iam_policy" "external_dns" {
  name        = "external-dns-policy"
  path        = "/"
  description = "Allows access to resources needed to run external-dns."

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "route53:ChangeResourceRecordSets"
        ]
        Resource = [
          data.aws_route53_zone.zone_selected.arn
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "route53:ListHostedZones",
          "route53:ListResourceRecordSets",
          "route53:ListTagsForResource"
        ]
        Resource = [
          "*"
        ]
      }
    ]
  })
}

# 3. Attach the permissions policy to the role
resource "aws_iam_role_policy_attachment" "external_dns" {
  role       = aws_iam_role.external_dns.name
  policy_arn = aws_iam_policy.external_dns.arn
}


# Deploy external-dns with helm
resource "helm_release" "external_dns" {
  name             = "external-dns"
  repository       = "https://kubernetes-sigs.github.io/external-dns/"
  chart            = "external-dns"
  namespace        = "kube-system"
  create_namespace = true
  version          = var.helm_external_dns_chart_version == "" ? null : var.helm_external_dns_chart_version

  values = [
    yamlencode({
      serviceAccount = {
        name = "external-dns"
        annotations = {
          "eks.amazonaws.com/role-arn" = aws_iam_role.external_dns.arn
        }
      }

      provider = "aws"

      policy = "sync"

      zoneType = "public"

      domainFilters = [
        var.domain
      ]

      txtOwnerId = "external-dns"
    })
  ]
  depends_on = [aws_eks_node_group.general]
}