# Docker Image - Prometheus AWS

## Development

### Managing CI keys

To encrypt a GPG key for use by CI:

```bash
openssl aes-256-cbc \
  -e \
  -md sha1 \
  -in ./config/secrets/ci/gpg.private \
  -out ./.github/gpg.private.enc \
  -k "<passphrase>"
```

To check decryption is working correctly:

```bash
openssl aes-256-cbc \
  -d \
  -md sha1 \
  -in ./.github/gpg.private.enc \
  -k "<passphrase>"
```
