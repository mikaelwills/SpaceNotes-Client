package pgpmobile

import (
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
