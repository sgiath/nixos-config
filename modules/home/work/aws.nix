{
  config,
  lib,
  pkgs,
  ...
}:
let
  pass = pkgs.pass-wayland.withExtensions (exts: [ exts.pass-otp ]);
  awscli = pkgs.awscli2;
  mfaCredFile = "/home/sgiath/.aws-cred";
  awsSecrets = pkgs.writeShellScriptBin "aws-secrets" ''
    set -euo pipefail
    umask 077

    mfa="arn:aws:iam::173509387151:mfa/filip"
    credential_file=${lib.escapeShellArg mfaCredFile}
    temporary_file="$(${pkgs.coreutils}/bin/mktemp "$credential_file.XXXXXX")"
    trap '${pkgs.coreutils}/bin/rm -f "$temporary_file"' EXIT

    token="$(${lib.getExe pass} otp 2fa/amazon/code)"
    ${lib.getExe awscli} sts get-session-token \
      --profile crazyegg \
      --serial-number "$mfa" \
      --token-code "$token" \
      --duration-seconds 43200 \
      | ${lib.getExe pkgs.jq} -e '.Credentials | select(type == "object") | . + {"Version": 1}' \
      > "$temporary_file"

    ${pkgs.coreutils}/bin/mv "$temporary_file" "$credential_file"
    trap - EXIT
    echo "AWS credentials updated"
  '';
  refreshMinute = config.sgiath.work.crazyegg.awsRefreshMinute;
in
{
  # Every host with CrazyEgg work enabled refreshes from the same OTP secret, and AWS
  # accepts each code only once, so hosts refreshing in the same 30 s window keep
  # failing each other. AdminMFA only allows sessions under 8 h of MFA age (the
  # session itself lasts 12 h), so a host that keeps losing gets AccessDenied while
  # `aws sts get-caller-identity` still works.
  options.sgiath.work.crazyegg.awsRefreshMinute = lib.mkOption {
    type = lib.types.ints.between 0 59;
    default = 0;
    description = "Minute of each hour the AWS session refresh runs; must differ between hosts.";
  };

  config = lib.mkIf config.sgiath.work.crazyegg.enable {
    programs.awscli = {
      enable = true;
      settings."default" = {
        region = "us-east-1";
        output = "json";
      };
      credentials = {
        "default"."credential_process" = "cat ${mfaCredFile}";
        "crazyegg"."credential_process" = "${lib.getExe pass} show aws/crazyegg";
      };
      package = awscli;
    };

    systemd.user = {
      services.aws-secrets = {
        Unit.Description = "Refresh AWS session credentials";
        Service = {
          Type = "oneshot";
          Environment = [ "PASSWORD_STORE_DIR=${config.xdg.dataHome}/password-store" ];
          ExecStart = lib.getExe awsSecrets;
        };
      };

      timers.aws-secrets = {
        Unit.Description = "Refresh AWS session credentials hourly";
        Timer = {
          OnBootSec = "1min";
          OnCalendar = "*:${toString refreshMinute}:00";
          Persistent = true;
          Unit = "aws-secrets.service";
        };
        Install.WantedBy = [ "timers.target" ];
      };
    };

    home = {
      packages = with pkgs; [
        awsSecrets
        jq
      ];

      # remotectl only reads and writes ~/.kube/config, so it stays a regular writable file
      # and the CrazyEgg clusters merge in from their own read-only file.
      sessionVariables.KUBECONFIG = "${config.home.homeDirectory}/.kube/config:${config.home.homeDirectory}/.kube/crazyegg";

      file = {
        ".kube/crazyegg".text = ''
          apiVersion: v1
          clusters:
            - cluster:
                certificate-authority-data: LS0tLS1CRUdJTiBDRVJUSUZJQ0FURS0tLS0tCk1JSUMvakNDQWVhZ0F3SUJBZ0lCQURBTkJna3Foa2lHOXcwQkFRc0ZBREFWTVJNd0VRWURWUVFERXdwcmRXSmwKY201bGRHVnpNQjRYRFRJeU1USXhOakUyTXpjeE1Wb1hEVE15TVRJeE16RTJNemN4TVZvd0ZURVRNQkVHQTFVRQpBeE1LYTNWaVpYSnVaWFJsY3pDQ0FTSXdEUVlKS29aSWh2Y05BUUVCQlFBRGdnRVBBRENDQVFvQ2dnRUJBTVNsCmwyWWl3blZWeDhFTmh6VkNrSUZBWUkyOG00NjEzbjEyOVNmeVFhMjVFMTNVT1VweUlKNTUzUUNBRzEwV0hEM1oKbzhXbTIvL3VUc1B5SUZHOVFaNkwzenNTMGdwQW1ibnBVSk1jMmJ5TlNsbWVuM0JWYmVTZkc0MEduZTltekxYTApTQTc2MWR1Y3R3MkJyTXhWM3ZPSEhhR0drUGRoeHBiVW9zU0VJVnhNYlNDZGk2SXlHMFhNcGxUSmxkZTFGdDlrCkxKdjlkMVlBRjlDYlRsYWNkdm81eVJDWWw4c0xnY0hzSkpHbVg3WUpsY2V3RDM3UW9hbXRNL0ZlS1BsL00rWVcKSEhnNVBjbCtKWjZVTVVQcG1DNm43TFZqK3VwZmZjdXhxcHl3d1dkeEM3emZ0MzFESW1SQVZ1K3AzbjI4eldINwpUc1VCbnVqbVJTa2xBRU9iWGFNQ0F3RUFBYU5aTUZjd0RnWURWUjBQQVFIL0JBUURBZ0trTUE4R0ExVWRFd0VCCi93UUZNQU1CQWY4d0hRWURWUjBPQkJZRUZMTkFoYmwyQW1HWmZsZ0xRZHQ2dkNyWmN2ZDRNQlVHQTFVZEVRUU8KTUF5Q0NtdDFZbVZ5Ym1WMFpYTXdEUVlKS29aSWh2Y05BUUVMQlFBRGdnRUJBQWJpMDcwYVFNSkw2bjJuNlZ4Uwo4ZlRCcmtxeU9LRFg0TmM2UEdMelFRcHh4cW92dzZISkNEeUNpcE5ENWFXU0tkU21hNWxKWUpqZHRoUU5RVWdjCjljcFlRdjhiWmF6OUNSR0dFWTJ6bi9NczR3U1pMMTY0SXZvZ3ZkRVVyRWgvSHN1VDE4Z1lDNFFMa3hJR2lYb3MKTkpEZkxHaVlrbWwxQjVYdEY0ZCtOZTFORjhCQk9mRk9UcjZLT3AvNEVBdC9Gam5MMDVDaElDalBIQnV2ckpoNApvenFtaXMwclBBc04rMm9LbFU0SWhKdzZBMmRPV2NxMmxnd1JaNXRxQU1VR01aa3YrYkdDY3ZNWjczWDZrZUVGCktJSU55R2JidS9SZFNHUFdJWjFIYzNCblJMeEtZclk4K0ltUnExdzdOMlhMOU5kakljRTNMSlRnMjNoK1dsVTcKZmdjPQotLS0tLUVORCBDRVJUSUZJQ0FURS0tLS0tCg==
                server: https://58E9D056E514C66B03932D888C2D4718.gr7.us-east-1.eks.amazonaws.com
              name: arn:aws:eks:us-east-1:173509387151:cluster/crazyegg-prod
            - cluster:
                certificate-authority-data: LS0tLS1CRUdJTiBDRVJUSUZJQ0FURS0tLS0tCk1JSUMvakNDQWVhZ0F3SUJBZ0lCQURBTkJna3Foa2lHOXcwQkFRc0ZBREFWTVJNd0VRWURWUVFERXdwcmRXSmwKY201bGRHVnpNQjRYRFRJeU1USXdPREU0TlRRd00xb1hEVE15TVRJd05URTROVFF3TTFvd0ZURVRNQkVHQTFVRQpBeE1LYTNWaVpYSnVaWFJsY3pDQ0FTSXdEUVlKS29aSWh2Y05BUUVCQlFBRGdnRVBBRENDQVFvQ2dnRUJBSzlyCnI4UHE2UktiOHBhR1cvNlhwWHRYSDAwMVJpdnNZTFlYSjZmclB2YlVMamwrVmFNQXF2bTNPWFppUlJFamVLR0gKR280V2tvUHNFUG5ScWs2ZjZnNHRqRHAvTHRiaDBYeE9iK3dtU2ZmbWlwRjd5RytaV015bzdTUWVQQ2gvdm9peAptSFVJYUZwN0pSWWNFc3BHUWpjVzgyYjhpbzNXM3NyS3pZM0V0em5ldkN1RE1NalBFakNrV250UWtTZHVDNmNOCkpyVmV5RUZxVFFNeUUrTzFtZkhwRjZJUzc0R042ZytMVnVhcXByRWV5OWo5QU1VblZDVDZEM0hqdFBFNDh1NDAKNGp3T0N5NDhIZHZRNS96R3ZDWFArNjh3ZCtaNzEwakxqa0oxa1lQbmJjSmVKbWVuODRxOU5aR1lrYTFpelgvNgpUYjhPeUJ6dDVLWER1MDlqSEdNQ0F3RUFBYU5aTUZjd0RnWURWUjBQQVFIL0JBUURBZ0trTUE4R0ExVWRFd0VCCi93UUZNQU1CQWY4d0hRWURWUjBPQkJZRUZMMkY0ZDk3eGhXVWk5NzJwY0N1NklXbjh5b2NNQlVHQTFVZEVRUU8KTUF5Q0NtdDFZbVZ5Ym1WMFpYTXdEUVlKS29aSWh2Y05BUUVMQlFBRGdnRUJBRTdpcWxJZXhHRkc4UGJ6SGp1MAovS2pCcHBJZDc5N0tpTnM5aTR5eVNLR2phQThOLzBud2ZSTmx2UDh5QXRTV1RBU2RTbFpVMXlJOHE5bzlvc3JOCkV4VzVQZXA4RFRLcnBLS2U5QWJwdEhjTzBrNjYvQUw3MGk0Q3ZWRFl5VjJVR0E1a01ZSVVlYmtDWTlaa3JhYjkKU1NWVmRaL0VVeWpoM3NOODhoK2t3bnVpRWFqWi9HbG1zb052MVlVQ2pxanZBQ3VWcG1hdDdvZXJ5c1gvWHBBcAo0Smk5R1VTMzI3MFZ2aXR1azhKY2pyWGQ3ejBJV2F1MW9VQnNSZUMwcTRqMjF4bmY5T1BIcmhVS2Z0YWRxRDZTCmpPV1hJNm41eXhLV1NacHd0ZDIxK3pWZkhqKzUwcHJ3VzVKTkhqciticlM0VmppbUhFL1ViN0hYUjNyWFBqRWIKaWpNPQotLS0tLUVORCBDRVJUSUZJQ0FURS0tLS0tCg==
                server: https://92A0ECA0544FDE239D1F13AD96C822EB.gr7.us-west-2.eks.amazonaws.com
              name: arn:aws:eks:us-west-2:173509387151:cluster/crazyegg-staging
          contexts:
            - context:
                cluster: arn:aws:eks:us-east-1:173509387151:cluster/crazyegg-prod
                user: arn:aws:eks:us-east-1:173509387151:cluster/crazyegg-prod
                namespace: prod
              name: arn:aws:eks:us-east-1:173509387151:cluster/crazyegg-prod
            - context:
                cluster: arn:aws:eks:us-west-2:173509387151:cluster/crazyegg-staging
                user: arn:aws:eks:us-west-2:173509387151:cluster/crazyegg-staging
                namespace: staging
              name: arn:aws:eks:us-west-2:173509387151:cluster/crazyegg-staging
          current-context: arn:aws:eks:us-east-1:173509387151:cluster/crazyegg-prod
          kind: Config
          preferences: {}
          users:
            - name: arn:aws:eks:us-east-1:173509387151:cluster/crazyegg-prod
              user:
                exec:
                  apiVersion: client.authentication.k8s.io/v1beta1
                  args:
                    - --region
                    - us-east-1
                    - eks
                    - get-token
                    - --cluster-name
                    - crazyegg-prod
                    - --output
                    - json
                  command: ${lib.getExe awscli}
            - name: arn:aws:eks:us-west-2:173509387151:cluster/crazyegg-staging
              user:
                exec:
                  apiVersion: client.authentication.k8s.io/v1beta1
                  args:
                    - --region
                    - us-west-2
                    - eks
                    - get-token
                    - --cluster-name
                    - crazyegg-staging
                    - --output
                    - json
                  command: ${lib.getExe awscli}
        '';
      };
    };
  };
}
