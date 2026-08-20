.PHONY: sparkle test build run preview

sparkle:
	./platforms/macos/Scripts/fetch-sparkle.sh

test: sparkle
	cd core && go test ./... && go vet ./...
	swift test --package-path platforms/macos

build: sparkle
	./platforms/macos/Scripts/build-app.sh

run: build
	open dist/Bren.app

preview: build
	dist/Bren.app/Contents/MacOS/Bren --preview
