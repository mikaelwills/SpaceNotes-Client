package pgpmobile

import (
	"os"
	"os/exec"
	"regexp"
	"sort"
	"strings"
	"testing"
)

func storePaths(t *testing.T) (pubkeys []byte, gpgID []byte) {
	t.Helper()
	home, _ := os.UserHomeDir()
	pub, err := os.ReadFile(home + "/.password-store/.gpg-pubkeys.asc")
	if err != nil {
		t.Skip("no .gpg-pubkeys.asc on this machine")
	}
	id, err := os.ReadFile(home + "/.password-store/.gpg-id")
	if err != nil {
		t.Skip("no .gpg-id on this machine")
	}
	return pub, id
}

var keyidPattern = regexp.MustCompile(`keyid ([0-9A-Fa-f]{16})`)

func pkeskKeyIDs(t *testing.T, ciphertext []byte) []string {
	t.Helper()
	tmp, err := os.CreateTemp(t.TempDir(), "msg-*.gpg")
	if err != nil {
		t.Fatalf("temp: %v", err)
	}
	if _, err := tmp.Write(ciphertext); err != nil {
		t.Fatalf("write temp: %v", err)
	}
	tmp.Close()

	out, err := exec.Command("gpg", "--list-packets", tmp.Name()).Output()
	if err != nil && len(out) == 0 {
		t.Fatalf("gpg --list-packets: %v", err)
	}

	var ids []string
	for _, line := range strings.Split(string(out), "\n") {
		if !strings.Contains(line, "pubkey enc packet") {
			continue
		}
		if m := keyidPattern.FindStringSubmatch(line); m != nil {
			ids = append(ids, strings.ToUpper(m[1]))
		}
	}
	sort.Strings(ids)
	return ids
}

func TestEncryptReachesEveryGpgIdRecipient(t *testing.T) {
	pubkeys, gpgID := storePaths(t)

	ciphertext, err := Encrypt([]byte("s3cr3t\nusername: mikael@deadeye.photo\n"), pubkeys, gpgID)
	if err != nil {
		t.Fatalf("encrypt: %v", err)
	}
	if len(ciphertext) == 0 {
		t.Fatal("encrypt returned no ciphertext")
	}

	got := pkeskKeyIDs(t, ciphertext)
	want, err := parseGpgID(gpgID)
	if err != nil {
		t.Fatalf("parse .gpg-id: %v", err)
	}
	sort.Strings(want)

	if len(got) != len(want) {
		t.Fatalf("PKESK count = %d, want %d (ids %v vs .gpg-id %v)", len(got), len(want), got, want)
	}
	if len(got) != 4 {
		t.Fatalf("PKESK count = %d, want 4 — a count of 1 locks three devices out permanently", len(got))
	}
	for i := range got {
		if got[i] != want[i] {
			t.Fatalf("recipient ids = %v, want %v", got, want)
		}
	}
}

func TestEncryptRefusesWhenAGpgIdRecipientHasNoKey(t *testing.T) {
	pubkeys, gpgID := storePaths(t)

	staged := strings.TrimRight(string(gpgID), "\n") + "\nDEADBEEFDEADBEEF!\n"

	ciphertext, err := Encrypt([]byte("s3cr3t\n"), pubkeys, []byte(staged))
	if err == nil {
		t.Fatal("encrypt succeeded with a recipient that has no public key")
	}
	if len(ciphertext) != 0 {
		t.Fatalf("encrypt returned %d bytes of ciphertext alongside an error", len(ciphertext))
	}
	if !strings.Contains(err.Error(), "DEADBEEFDEADBEEF") {
		t.Fatalf("error does not name the missing recipient: %v", err)
	}
}

func TestEncryptRefusesEmptyPlaintext(t *testing.T) {
	pubkeys, gpgID := storePaths(t)

	ciphertext, err := Encrypt(nil, pubkeys, gpgID)
	if err == nil {
		t.Fatal("encrypt accepted empty plaintext")
	}
	if len(ciphertext) != 0 {
		t.Fatalf("encrypt returned %d bytes alongside an error", len(ciphertext))
	}
}

func TestEncryptRefusesEmptyGpgId(t *testing.T) {
	pubkeys, _ := storePaths(t)

	ciphertext, err := Encrypt([]byte("s3cr3t\n"), pubkeys, []byte("\n\n"))
	if err == nil {
		t.Fatal("encrypt accepted an empty .gpg-id")
	}
	if len(ciphertext) != 0 {
		t.Fatalf("encrypt returned %d bytes alongside an error", len(ciphertext))
	}
}

func TestEncryptOutputIsReadableByGpgAndUncompressed(t *testing.T) {
	pubkeys, gpgID := storePaths(t)

	plaintext := "s3cr3t\nusername: mikael@deadeye.photo\nurl: https://www.zoopla.co.uk/account/login\n"

	ciphertext, err := Encrypt([]byte(plaintext), pubkeys, gpgID)
	if err != nil {
		t.Fatalf("encrypt: %v", err)
	}

	tmp, err := os.CreateTemp(t.TempDir(), "msg-*.gpg")
	if err != nil {
		t.Fatalf("temp: %v", err)
	}
	if _, err := tmp.Write(ciphertext); err != nil {
		t.Fatalf("write temp: %v", err)
	}
	tmp.Close()

	packets, err := exec.Command("gpg", "--list-packets", tmp.Name()).Output()
	if err != nil && len(packets) == 0 {
		t.Fatalf("gpg --list-packets: %v", err)
	}
	if strings.Contains(string(packets), "compressed packet") {
		t.Fatal("output is compressed; pass entries must not be")
	}

	out, err := exec.Command("gpg", "--batch", "--yes", "--decrypt", tmp.Name()).Output()
	if err != nil {
		t.Skipf("gpg -d needs the private key / pinentry on this machine: %v", err)
	}
	if string(out) != plaintext {
		t.Fatalf("gpg -d returned %q, want %q", string(out), plaintext)
	}
}
