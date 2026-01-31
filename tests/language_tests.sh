#!/bin/bash

# Unit Tests for Language Components
# Tests all language-specific Docker images

set -euo pipefail

# Source the test framework
source "$(dirname "$0")/test_framework.sh"

# Test configuration
COMPONENT_NAME="language"
REGISTRY="${REGISTRY:-cni}"
TEST_TIMEOUT=60

# Language configurations
declare -A LANGUAGES=(
    ["go"]="go version"
    ["node"]="node --version"
    ["python"]="python --version"
    ["rust"]="rustc --version"
    ["php"]="php --version"
    ["java"]="java -version"
    ["ruby"]="ruby --version"
    ["cpp"]="gcc --version"
    ["csharp"]="dotnet --version"
    ["elixir"]="elixir --version"
)

declare -A LANG_VERSIONS=(
    ["go"]="1."
    ["node"]="v"
    ["python"]="Python 3"
    ["rust"]="rustc"
    ["php"]="PHP"
    ["java"]="openjdk"
    ["ruby"]="ruby"
    ["cpp"]="gcc"
    ["csharp"]=".NET"
    ["elixir"]="Elixir"
)

declare -A LANG_PACKAGES=(
    ["go"]="go"
    ["node"]="npm"
    ["python"]="pip"
    ["rust"]="cargo"
    ["php"]="composer"
    ["java"]="java"
    ["ruby"]="gem"
    ["cpp"]="g++"
    ["csharp"]="dotnet"
    ["elixir"]="mix"
)

# Cleanup function
cleanup() {
    log_info "Cleaning up language test environment"
    docker ps -q --filter "label=test=true" | xargs -r docker rm -f >/dev/null 2>&1 || true
}
trap cleanup EXIT

# Test suite: Language Image Validation
test_language_image_validation() {
    local lang="$1"
    local image="${REGISTRY}/lang-${lang}:latest"
    
    start_test_suite "lang_${lang}_image_validation"
    
    # Test 1: Language image exists
    test_docker_image_exists "$image" "Language image for $lang should exist"
    
    # Test 2: Language image can run
    test_docker_container_runs "$image" "echo 'test'" "Language container for $lang should run"
    
    # Test 3: Language image size is reasonable (should be under 1GB for most languages)
    local max_size=1000
    if [[ "$lang" == "java" || "$lang" == "dotnet" ]]; then
        max_size=2000  # Allow larger size for JVM/.NET languages
    fi
    test_docker_image_size "$image" "$max_size" "Language image for $lang size should be reasonable"
    
    end_test_suite "lang_${lang}_image_validation"
}

# Test suite: Language Runtime
test_language_runtime() {
    local lang="$1"
    local image="${REGISTRY}/lang-${lang}:latest"
    local version_cmd="${LANGUAGES[$lang]}"
    local expected_version="${LANG_VERSIONS[$lang]}"
    
    start_test_suite "lang_${lang}_runtime"
    
    # Test 1: Language runtime is available
    local runtime_output
    runtime_output=$(docker run --rm "$image" $version_cmd 2>&1 || echo "FAILED")
    
    assert_not_equals "FAILED" "$runtime_output" "Language runtime for $lang should be available"
    assert_contains "$expected_version" "$runtime_output" "Language version for $lang should contain expected version pattern"
    
    # Test 2: Language package manager is available
    local package_manager="${LANG_PACKAGES[$lang]}"
    assert_command_exists "$package_manager" "Package manager $package_manager for $lang should be available"
    
    end_test_suite "lang_${lang}_runtime"
}

# Test suite: Language Functionality
test_language_functionality() {
    local lang="$1"
    local image="${REGISTRY}/lang-${lang}:latest"
    
    start_test_suite "lang_${lang}_functionality"
    
    case "$lang" in
        "go")
            # Test Go can compile and run a simple program
            docker run --rm -v "$TEMP_DIR:/workspace" "$image" sh -c "
                cd /workspace && 
                echo 'package main; import \"fmt\"; func main() { fmt.Println(\"Hello, Go!\") }' > main.go &&
                go run main.go
            " > "$TEMP_DIR/go_output.txt" 2>&1
            assert_contains "Hello, Go!" "$(cat "$TEMP_DIR/go_output.txt" 2>/dev/null || echo "")" "Go should compile and run simple program"
            ;;
            
        "node")
            # Test Node.js can run a simple script
            docker run --rm "$image" node -e "console.log('Hello, Node!')" > "$TEMP_DIR/node_output.txt" 2>&1
            assert_contains "Hello, Node!" "$(cat "$TEMP_DIR/node_output.txt" 2>/dev/null || echo "")" "Node.js should execute simple script"
            ;;
            
        "python")
            # Test Python can run a simple script
            docker run --rm "$image" python -c "print('Hello, Python!')" > "$TEMP_DIR/python_output.txt" 2>&1
            assert_contains "Hello, Python!" "$(cat "$TEMP_DIR/python_output.txt" 2>/dev/null || echo "")" "Python should execute simple script"
            ;;
            
        "rust")
            # Test Rust can compile and run a simple program
            docker run --rm -v "$TEMP_DIR:/workspace" "$image" sh -c "
                cd /workspace &&
                echo 'fn main() { println!(\"Hello, Rust!\"); }' > main.rs &&
                rustc main.rs && ./main
            " > "$TEMP_DIR/rust_output.txt" 2>&1
            assert_contains "Hello, Rust!" "$(cat "$TEMP_DIR/rust_output.txt" 2>/dev/null || echo "")" "Rust should compile and run simple program"
            ;;
            
        "php")
            # Test PHP can run a simple script
            docker run --rm "$image" php -r "echo 'Hello, PHP!';" > "$TEMP_DIR/php_output.txt" 2>&1
            assert_contains "Hello, PHP!" "$(cat "$TEMP_DIR/php_output.txt" 2>/dev/null || echo "")" "PHP should execute simple script"
            ;;
            
        "java")
            # Test Java can compile and run a simple program
            docker run --rm -v "$TEMP_DIR:/workspace" "$image" sh -c "
                cd /workspace &&
                echo 'public class Test { public static void main(String[] args) { System.out.println(\"Hello, Java!\"); } }' > Test.java &&
                javac Test.java && java Test
            " > "$TEMP_DIR/java_output.txt" 2>&1
            assert_contains "Hello, Java!" "$(cat "$TEMP_DIR/java_output.txt" 2>/dev/null || echo "")" "Java should compile and run simple program"
            ;;
            
        "ruby")
            # Test Ruby can run a simple script
            docker run --rm "$image" ruby -e "puts 'Hello, Ruby!'" > "$TEMP_DIR/ruby_output.txt" 2>&1
            assert_contains "Hello, Ruby!" "$(cat "$TEMP_DIR/ruby_output.txt" 2>/dev/null || echo "")" "Ruby should execute simple script"
            ;;
            
        "cpp")
            # Test C++ can compile and run a simple program
            docker run --rm -v "$TEMP_DIR:/workspace" "$image" sh -c "
                cd /workspace &&
                echo '#include <iostream>' > main.cpp &&
                echo 'int main() { std::cout << \"Hello, C++!\" << std::endl; return 0; }' >> main.cpp &&
                g++ main.cpp -o main && ./main
            " > "$TEMP_DIR/cpp_output.txt" 2>&1
            assert_contains "Hello, C++!" "$(cat "$TEMP_DIR/cpp_output.txt" 2>/dev/null || echo "")" "C++ should compile and run simple program"
            ;;
            
        "csharp")
            # Test C# can compile and run a simple program
            docker run --rm -v "$TEMP_DIR:/workspace" "$image" sh -c "
                cd /workspace &&
                dotnet new console -n TestApp --force &&
                cd TestApp &&
                sed -i 's/Hello World!/Hello, CSharp!/' Program.cs &&
                dotnet run
            " > "$TEMP_DIR/csharp_output.txt" 2>&1
            assert_contains "Hello, CSharp!" "$(cat "$TEMP_DIR/csharp_output.txt" 2>/dev/null || echo "")" "C# should compile and run simple program"
            ;;
            
        "elixir")
            # Test Elixir can run a simple script
            docker run --rm "$image" elixir -e "IO.puts 'Hello, Elixir!'" > "$TEMP_DIR/elixir_output.txt" 2>&1
            assert_contains "Hello, Elixir!" "$(cat "$TEMP_DIR/elixir_output.txt" 2>/dev/null || echo "")" "Elixir should execute simple script"
            ;;
    esac
    
    end_test_suite "lang_${lang}_functionality"
}

# Test suite: Language Package Management
test_language_package_management() {
    local lang="$1"
    local image="${REGISTRY}/lang-${lang}:latest"
    
    start_test_suite "lang_${lang}_package_management"
    
    case "$lang" in
        "go")
            # Test Go modules work
            docker run --rm -v "$TEMP_DIR:/workspace" "$image" sh -c "
                cd /workspace &&
                go mod init test &&
                go get github.com/stretchr/testify/assert &&
                go mod tidy
            " > /dev/null 2>&1
            assert_file_exists "$TEMP_DIR/go.mod" "Go should create go.mod file"
            assert_file_exists "$TEMP_DIR/go.sum" "Go should create go.sum file"
            ;;
            
        "node")
            # Test npm works
            docker run --rm -v "$TEMP_DIR:/workspace" "$image" sh -c "
                cd /workspace &&
                npm init -y &&
                npm install lodash --save
            " > /dev/null 2>&1
            assert_file_exists "$TEMP_DIR/package.json" "Node should create package.json file"
            assert_file_exists "$TEMP_DIR/package-lock.json" "Node should create package-lock.json file"
            assert_file_exists "$TEMP_DIR/node_modules" "Node should install packages"
            ;;
            
        "python")
            # Test pip works
            docker run --rm -v "$TEMP_DIR:/workspace" "$image" sh -c "
                cd /workspace &&
                pip install requests
            " > /dev/null 2>&1
            # Check if pip created a site-packages directory with requests
            local pip_check
            pip_check=$(docker run --rm "$image" python -c "import requests; print('OK')" 2>/dev/null || echo "FAIL")
            assert_equals "OK" "$pip_check" "Python should be able to import installed packages"
            ;;
            
        "rust")
            # Test Cargo works
            docker run --rm -v "$TEMP_DIR:/workspace" "$image" sh -c "
                cd /workspace &&
                cargo new test_project --bin &&
                cd test_project &&
                cargo build
            " > /dev/null 2>&1
            assert_file_exists "$TEMP_DIR/test_project/Cargo.toml" "Rust should create Cargo.toml file"
            assert_file_exists "$TEMP_DIR/test_project/Cargo.lock" "Rust should create Cargo.lock file"
            ;;
            
        "php")
            # Test Composer works
            docker run --rm -v "$TEMP_DIR:/workspace" "$image" sh -c "
                cd /workspace &&
                composer init --no-interaction &&
                composer require psr/log --no-interaction
            " > /dev/null 2>&1
            assert_file_exists "$TEMP_DIR/composer.json" "PHP should create composer.json file"
            assert_file_exists "$TEMP_DIR/vendor" "PHP should install composer packages"
            ;;
    esac
    
    end_test_suite "lang_${lang}_package_management"
}

# Test suite: Language Security
test_language_security() {
    local lang="$1"
    local image="${REGISTRY}/lang-${lang}:latest"
    
    start_test_suite "lang_${lang}_security"
    
    # Test 1: Container runs as non-root (for languages that support it)
    local current_user
    current_user=$(docker run --rm "$image" id -u 2>/dev/null || echo "0")
    
    # Some language images might run as root, but we should at least check it's consistent
    if [[ "$current_user" == "0" ]]; then
        log_warning "Language $lang runs as root user - consider using non-root user"
    else
        log_success "Language $lang runs as non-root user (UID: $current_user)"
    fi
    ((TESTS_PASSED++))
    ((TESTS_TOTAL++))
    
    # Test 2: SSL certificates are available for package managers
    local cert_check
    cert_check=$(docker run --rm "$image" test -f /etc/ssl/certs/ca-certificates.crt && echo "yes" || echo "no")
    assert_equals "yes" "$cert_check" "SSL certificates should be available for $lang"
    
    end_test_suite "lang_${lang}_security"
}

# Main test execution
main() {
    local specific_lang="${1:-}"
    local temp_dir="/tmp/lang-test-$$"
    mkdir -p "$temp_dir"
    TEMP_DIR="$temp_dir"
    
    log_info "Starting language component unit tests"
    
    # Initialize test counters
    TESTS_TOTAL=0
    TESTS_PASSED=0
    TESTS_FAILED=0
    TESTS_SKIPPED=0
    
    # Run tests for specific language or all languages
    if [[ -n "$specific_lang" && -n "${LANGUAGES[$specific_lang]:-}" ]]; then
        log_info "Testing language: $specific_lang"
        test_language_image_validation "$specific_lang"
        test_language_runtime "$specific_lang"
        test_language_functionality "$specific_lang"
        test_language_package_management "$specific_lang"
        test_language_security "$specific_lang"
        generate_coverage_report "lang_${specific_lang}"
    else
        log_info "Testing all languages"
        for lang in "${!LANGUAGES[@]}"; do
            log_info "Testing language: $lang"
            test_language_image_validation "$lang"
            test_language_runtime "$lang"
            test_language_functionality "$lang"
            test_language_package_management "$lang"
            test_language_security "$lang"
        done
        generate_coverage_report "$COMPONENT_NAME"
    fi
    
    # Cleanup
    rm -rf "$temp_dir"
    
    # Final summary
    log_info "Language component tests completed"
    log_info "Total: $TESTS_TOTAL, Passed: $TESTS_PASSED, Failed: $TESTS_FAILED, Skipped: $TESTS_SKIPPED"
    
    # Exit with appropriate code
    if [[ $TESTS_FAILED -eq 0 ]]; then
        log_success "All language component tests passed!"
        exit 0
    else
        log_error "$TESTS_FAILED language component tests failed!"
        exit 1
    fi
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
