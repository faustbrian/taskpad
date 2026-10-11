# List available commands.
default:
    @just --list

# Run the test suite.
test:
    ./scripts/test.sh

# Build the native app bundle from source.
build:
    ./scripts/build.sh

# Build from source and open the app.
run: build
    open build/TaskPad.app
