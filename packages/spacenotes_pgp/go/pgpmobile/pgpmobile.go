package pgpmobile

import (
	"fmt"
	"sort"
	"strings"
	"time"

	openpgp "github.com/ProtonMail/go-crypto/openpgp/v2"
	"github.com/ProtonMail/gopenpgp/v3/crypto"
)

// Decrypt returns the plaintext of an OpenPGP message using the given private
// key. Both arguments and the result are raw bytes; the key may be armored or
// binary. Returns an error when the key cannot read the message.
func Decrypt(ciphertext []byte, privateKey []byte) ([]byte, error) {
	key, err := crypto.NewKey(privateKey)
	if err != nil {
		return nil, err
	}
	defer key.ClearPrivateParams()

	pgp := crypto.PGP()
	decryptor, err := pgp.Decryption().DecryptionKey(key).New()
	if err != nil {
		return nil, err
	}

	result, err := decryptor.Decrypt(ciphertext, crypto.Auto)
	if err != nil {
		return nil, err
	}

	return result.Bytes(), nil
}

func Encrypt(plaintext []byte, publicKeys []byte, gpgID []byte) ([]byte, error) {
	if len(plaintext) == 0 {
		return nil, fmt.Errorf("pgpmobile: refusing to encrypt empty plaintext")
	}

	wanted, err := parseGpgID(gpgID)
	if err != nil {
		return nil, err
	}

	ring, present, err := encryptionRingPerSubkey(publicKeys)
	if err != nil {
		return nil, err
	}

	var missing []string
	for _, id := range wanted {
		if !present[id] {
			missing = append(missing, id)
		}
	}
	if len(missing) > 0 {
		sort.Strings(missing)
		return nil, fmt.Errorf(
			"pgpmobile: refusing to encrypt, no public key for %d of %d .gpg-id recipients: %s",
			len(missing), len(wanted), strings.Join(missing, ", "))
	}

	enc, err := crypto.PGP().Encryption().Recipients(ring).New()
	if err != nil {
		return nil, err
	}
	msg, err := enc.Encrypt(plaintext)
	if err != nil {
		return nil, err
	}

	return msg.Bytes(), nil
}

func encryptionRingPerSubkey(publicKeys []byte) (*crypto.KeyRing, map[string]bool, error) {
	key, err := crypto.NewKey(publicKeys)
	if err != nil {
		return nil, nil, err
	}
	entity := key.GetEntity()
	if entity == nil {
		return nil, nil, fmt.Errorf("pgpmobile: public key material holds no entity")
	}

	ring, err := crypto.NewKeyRing(nil)
	if err != nil {
		return nil, nil, err
	}

	now := time.Now()
	present := make(map[string]bool, len(entity.Subkeys))
	for i := range entity.Subkeys {
		single := &openpgp.Entity{
			PrimaryKey:       entity.PrimaryKey,
			Identities:       entity.Identities,
			Revocations:      entity.Revocations,
			DirectSignatures: entity.DirectSignatures,
			Subkeys:          []openpgp.Subkey{entity.Subkeys[i]},
		}
		if _, err := single.EncryptionKeyWithError(now, nil); err != nil {
			continue
		}
		k, err := crypto.NewKeyFromEntity(single)
		if err != nil {
			return nil, nil, err
		}
		if err := ring.AddKey(k); err != nil {
			return nil, nil, err
		}
		present[strings.ToUpper(entity.Subkeys[i].PublicKey.KeyIdString())] = true
	}

	return ring, present, nil
}

func parseGpgID(gpgID []byte) ([]string, error) {
	var ids []string
	seen := make(map[string]bool)
	for _, line := range strings.Split(string(gpgID), "\n") {
		id := strings.ToUpper(strings.TrimSuffix(strings.TrimSpace(line), "!"))
		if id == "" || strings.HasPrefix(id, "#") || seen[id] {
			continue
		}
		seen[id] = true
		ids = append(ids, id)
	}
	if len(ids) == 0 {
		return nil, fmt.Errorf("pgpmobile: .gpg-id names no recipients")
	}
	return ids, nil
}
