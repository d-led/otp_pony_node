package main

import (
	"fmt"
	"io/ioutil"
	"os"
	"path"
	"path/filepath"
	"strings"
)

func joinAndNormalizePath(root string, postfix string) string {
	return filepath.Clean(path.Join(root, postfix))
}

func latestPrefixedFolderIn(root string, prefix string) string {
	dirs, err := ioutil.ReadDir(root)
	if err != nil {
		return ""
	}

	var candidateFolder string
	var candidateTime int64 = -1

	for _, dir := range dirs {
		d, err := os.Stat(joinAndNormalizePath(root, dir.Name()))
		if err != nil || !d.IsDir() || !strings.HasPrefix(dir.Name(), prefix) {
			continue
		}
		t := d.ModTime().Unix()
		if t > candidateTime {
			candidateTime = t
			candidateFolder = filepath.Clean(path.Join(root, d.Name()))
		}
	}

	return candidateFolder
}

func main() {
	erl := latestPrefixedFolderIn("C:\\Program Files\\", "erl")
	if erl == "" {
		return
	}
	erl_interface := latestPrefixedFolderIn(joinAndNormalizePath(erl, "\\lib"), "erl_interface")
	fmt.Println(erl_interface)
}
