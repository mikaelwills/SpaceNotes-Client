package pgpmobile

import (
	"os"
	"os/exec"
	"strings"
	"testing"
)

func TestDecryptRealCredential(t *testing.T) {
	home, _ := os.UserHomeDir()
	entry := home + "/.password-store/www.zoopla.co.uk/mikael@deadeye.photo.gpg"

	ciphertext, err := os.ReadFile(entry)
	if err != nil {
		t.Skip("no store on this machine")
	}

	keyPath := os.Getenv("PGP_TEST_KEY")
	if keyPath == "" {
		t.Skip("set PGP_TEST_KEY to a stripped subkey export")
	}
	privateKey, err := os.ReadFile(keyPath)
	if err != nil {
		t.Fatalf("read key: %v", err)
	}

	got, err := Decrypt(ciphertext, privateKey)
	if err != nil {
		t.Fatalf("decrypt: %v", err)
	}

	want, err := exec.Command("gpg", "--decrypt", entry).Output()
	if err != nil {
		t.Fatalf("gpg reference decrypt: %v", err)
	}

	if strings.TrimSpace(string(got)) != strings.TrimSpace(string(want)) {
		t.Fatalf("plaintext mismatch")
	}
}
