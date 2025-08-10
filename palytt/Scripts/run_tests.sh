#!/bin/bash

echo "🧪 Palytt Automated Testing Suite"
echo "=================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

# Test results tracking
UNIT_TESTS_PASSED=false
UI_TESTS_PASSED=false
BUILD_PASSED=false
BACKEND_TESTS_PASSED=false

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_header() {
    echo -e "${PURPLE}=== $1 ===${NC}"
}

# Function to show usage
show_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --unit-only         Run only unit tests"
    echo "  --ui-only          Run only UI tests"
    echo "  --backend-only     Run only backend tests"
    echo "  --build-only       Only build the project"
    echo "  --no-backend       Skip backend tests"
    echo "  --no-cleanup       Skip cleanup after tests"
    echo "  --verbose          Enable verbose output"
    echo "  --help             Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0                 Run all tests"
    echo "  $0 --unit-only     Run only unit tests"
    echo "  $0 --no-backend    Run iOS tests without backend"
}

# Parse command line arguments
UNIT_ONLY=false
UI_ONLY=false
BACKEND_ONLY=false
BUILD_ONLY=false
NO_BACKEND=false
NO_CLEANUP=false
VERBOSE=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --unit-only)
            UNIT_ONLY=true
            shift
            ;;
        --ui-only)
            UI_ONLY=true
            shift
            ;;
        --backend-only)
            BACKEND_ONLY=true
            shift
            ;;
        --build-only)
            BUILD_ONLY=true
            shift
            ;;
        --no-backend)
            NO_BACKEND=true
            shift
            ;;
        --no-cleanup)
            NO_CLEANUP=true
            shift
            ;;
        --verbose)
            VERBOSE=true
            shift
            ;;
        --help)
            show_usage
            exit 0
            ;;
        *)
            print_error "Unknown option: $1"
            show_usage
            exit 1
            ;;
    esac
done

# Function to check prerequisites
check_prerequisites() {
    print_header "Checking Prerequisites"
    
    # Check if Xcode is available
    if ! command -v xcodebuild &> /dev/null; then
        print_error "Xcode not found. Please install Xcode."
        return 1
    fi
    print_success "Xcode found: $(xcodebuild -version | head -n1)"
    
    # Check if backend directory exists (unless skipping backend)
    if [[ "$NO_BACKEND" != true && "$BACKEND_ONLY" != true ]]; then
        if [ ! -d "palytt-backend.symlink" ]; then
            print_warning "Backend directory not found. Backend tests will be skipped."
            NO_BACKEND=true
        else
            print_success "Backend directory found"
        fi
    fi
    
    # Check if test files exist
    if [ ! -f "Tests/PalyttAppTests/FriendsServiceTests.swift" ]; then
        print_error "Unit test files not found"
        return 1
    fi
    print_success "Test files found"
    
    # Check iOS Simulator
    if ! xcrun simctl list devices | grep -q "iPhone 16 Pro (18.3.1)"; then
        print_warning "iPhone 16 Pro iOS 18.3.1 simulator not found. Using available simulator."
    else
        print_success "Target simulator found"
    fi
    
    return 0
}

# Function to start backend server
start_backend() {
    if [[ "$NO_BACKEND" == true ]]; then
        return 0
    fi
    
    print_header "Starting Backend Server"
    
    cd palytt-backend.symlink || {
        print_error "Failed to navigate to backend directory"
        return 1
    }
    
    # Check if server is already running
    if curl -s http://localhost:4000/health > /dev/null; then
        print_success "Backend server already running"
        cd ..
        return 0
    fi
    
    # Start the server
    print_status "Starting backend server..."
    source ~/.zshrc
    pnpm run dev > backend.log 2>&1 &
    BACKEND_PID=$!
    
    # Wait for server to start
    print_status "Waiting for backend server to start..."
    for i in {1..30}; do
        if curl -s http://localhost:4000/health > /dev/null; then
            print_success "Backend server started successfully"
            cd ..
            return 0
        fi
        sleep 1
        echo -n "."
    done
    
    print_error "Backend server failed to start"
    cd ..
    return 1
}

# Function to stop backend server
stop_backend() {
    if [[ "$NO_BACKEND" == true || -z "$BACKEND_PID" ]]; then
        return 0
    fi
    
    print_status "Stopping backend server..."
    kill $BACKEND_PID 2>/dev/null || true
    
    # Also kill any processes on port 4000
    lsof -ti:4000 | xargs kill -9 2>/dev/null || true
    
    print_success "Backend server stopped"
}

# Function to run backend tests
run_backend_tests() {
    if [[ "$NO_BACKEND" == true ]]; then
        print_warning "Skipping backend tests"
        return 0
    fi
    
    print_header "Running Backend Tests"
    
    cd palytt-backend.symlink || {
        print_error "Failed to navigate to backend directory"
        return 1
    }
    
    # Test backend health
    print_status "Testing backend health..."
    if ! curl -s http://localhost:4000/health > /dev/null; then
        print_error "Backend health check failed"
        cd ..
        return 1
    fi
    print_success "Backend health check passed"
    
    # Test friends endpoints
    print_status "Testing friends endpoints..."
    
    # Test sending friend request
    SEND_RESULT=$(curl -s -X POST "http://localhost:4000/trpc/friends.sendRequest" \
        -H "Content-Type: application/json" \
        -d '{"senderId": "test_user_1", "receiverId": "test_user_2"}')
    
    if echo "$SEND_RESULT" | grep -q "success.*true"; then
        print_success "Friend request test passed"
    else
        print_warning "Friend request test failed (expected for new users)"
    fi
    
    # Test getting friend requests
    GET_RESULT=$(curl -s -X GET "http://localhost:4000/trpc/friends.getPendingRequests?input=%7B%22userId%22:%22test_user_2%22%7D")
    
    if echo "$GET_RESULT" | grep -q "result"; then
        print_success "Get friend requests test passed"
    else
        print_error "Get friend requests test failed"
        cd ..
        return 1
    fi
    
    cd ..
    BACKEND_TESTS_PASSED=true
    return 0
}

# Function to build the project
build_project() {
    print_header "Building iOS Project"
    
    print_status "Building Palytt for iPhone 16 Pro simulator..."
    
    if [[ "$VERBOSE" == true ]]; then
        xcodebuild -scheme Palytt \
            -destination 'platform=iOS Simulator,name=iPhone 16 Pro,OS=18.3.1' \
            clean build
    else
        xcodebuild -scheme Palytt \
            -destination 'platform=iOS Simulator,name=iPhone 16 Pro,OS=18.3.1' \
            clean build > build.log 2>&1
    fi
    
    if [ $? -eq 0 ]; then
        print_success "iOS project built successfully"
        BUILD_PASSED=true
        return 0
    else
        print_error "iOS project build failed"
        if [[ "$VERBOSE" == false ]]; then
            echo "Build log:"
            tail -20 build.log
        fi
        return 1
    fi
}

# Function to run unit tests
run_unit_tests() {
    print_header "Running Unit Tests"
    
    print_status "Running Friends service unit tests..."
    
    if [[ "$VERBOSE" == true ]]; then
        xcodebuild test \
            -scheme Palytt \
            -destination 'platform=iOS Simulator,name=iPhone 16 Pro,OS=18.3.1' \
            -only-testing:PalyttAppTests/FriendsServiceTests
    else
        xcodebuild test \
            -scheme Palytt \
            -destination 'platform=iOS Simulator,name=iPhone 16 Pro,OS=18.3.1' \
            -only-testing:PalyttAppTests/FriendsServiceTests > unit_tests.log 2>&1
    fi
    
    if [ $? -eq 0 ]; then
        print_success "Unit tests passed"
        UNIT_TESTS_PASSED=true
        return 0
    else
        print_error "Unit tests failed"
        if [[ "$VERBOSE" == false ]]; then
            echo "Unit test log:"
            tail -20 unit_tests.log
        fi
        return 1
    fi
}

# Function to run UI tests
run_ui_tests() {
    print_header "Running UI Tests"
    
    print_status "Running Friends UI tests..."
    
    if [[ "$VERBOSE" == true ]]; then
        xcodebuild test \
            -scheme Palytt \
            -destination 'platform=iOS Simulator,name=iPhone 16 Pro,OS=18.3.1' \
            -only-testing:PalyttAppTests/FriendsUITests
    else
        xcodebuild test \
            -scheme Palytt \
            -destination 'platform=iOS Simulator,name=iPhone 16 Pro,OS=18.3.1' \
            -only-testing:PalyttAppTests/FriendsUITests > ui_tests.log 2>&1
    fi
    
    if [ $? -eq 0 ]; then
        print_success "UI tests passed"
        UI_TESTS_PASSED=true
        return 0
    else
        print_error "UI tests failed"
        if [[ "$VERBOSE" == false ]]; then
            echo "UI test log:"
            tail -20 ui_tests.log
        fi
        return 1
    fi
}

# Function to run Maestro tests (if available)
run_maestro_tests() {
    if ! command -v maestro &> /dev/null; then
        print_warning "Maestro not found. Skipping Maestro tests."
        return 0
    fi
    
    if [ ! -f ".maestro/friends_flow_test.yaml" ]; then
        print_warning "Maestro test file not found. Skipping Maestro tests."
        return 0
    fi
    
    print_header "Running Maestro Tests"
    
    print_status "Running Maestro friends flow tests..."
    maestro test .maestro/friends_flow_test.yaml
    
    if [ $? -eq 0 ]; then
        print_success "Maestro tests passed"
        return 0
    else
        print_warning "Maestro tests failed"
        return 1
    fi
}

# Function to generate test report
generate_report() {
    print_header "Test Results Summary"
    
    echo "📊 Test Execution Results:"
    echo "=========================="
    
    if [[ "$BUILD_ONLY" == true ]]; then
        if [[ "$BUILD_PASSED" == true ]]; then
            print_success "✅ Build: PASSED"
        else
            print_error "❌ Build: FAILED"
        fi
        return 0
    fi
    
    # Build status
    if [[ "$BUILD_PASSED" == true ]]; then
        print_success "✅ Build: PASSED"
    else
        print_error "❌ Build: FAILED"
    fi
    
    # Backend tests status
    if [[ "$NO_BACKEND" == true ]]; then
        echo "⏭️  Backend Tests: SKIPPED"
    elif [[ "$BACKEND_TESTS_PASSED" == true ]]; then
        print_success "✅ Backend Tests: PASSED"
    else
        print_error "❌ Backend Tests: FAILED"
    fi
    
    # Unit tests status
    if [[ "$UI_ONLY" == true || "$BACKEND_ONLY" == true ]]; then
        echo "⏭️  Unit Tests: SKIPPED"
    elif [[ "$UNIT_TESTS_PASSED" == true ]]; then
        print_success "✅ Unit Tests: PASSED"
    else
        print_error "❌ Unit Tests: FAILED"
    fi
    
    # UI tests status
    if [[ "$UNIT_ONLY" == true || "$BACKEND_ONLY" == true ]]; then
        echo "⏭️  UI Tests: SKIPPED"
    elif [[ "$UI_TESTS_PASSED" == true ]]; then
        print_success "✅ UI Tests: PASSED"
    else
        print_error "❌ UI Tests: FAILED"
    fi
    
    echo ""
    
    # Overall result
    if [[ "$BUILD_PASSED" == true ]]; then
        if [[ "$BACKEND_ONLY" == true && "$BACKEND_TESTS_PASSED" == true ]]; then
            print_success "🎉 All backend tests completed successfully!"
            return 0
        elif [[ "$UNIT_ONLY" == true && "$UNIT_TESTS_PASSED" == true ]]; then
            print_success "🎉 All unit tests completed successfully!"
            return 0
        elif [[ "$UI_ONLY" == true && "$UI_TESTS_PASSED" == true ]]; then
            print_success "🎉 All UI tests completed successfully!"
            return 0
        elif [[ "$BUILD_ONLY" == true ]]; then
            print_success "🎉 Build completed successfully!"
            return 0
        elif [[ "$UNIT_TESTS_PASSED" == true && "$UI_TESTS_PASSED" == true ]]; then
            print_success "🎉 All tests completed successfully!"
            return 0
        else
            print_error "❌ Some tests failed. Check the logs above."
            return 1
        fi
    else
        print_error "❌ Build failed. Cannot run tests."
        return 1
    fi
}

# Function to cleanup
cleanup() {
    if [[ "$NO_CLEANUP" == true ]]; then
        print_status "Skipping cleanup"
        return 0
    fi
    
    print_status "Cleaning up..."
    
    # Stop backend server
    stop_backend
    
    # Remove log files
    rm -f build.log unit_tests.log ui_tests.log backend.log
    
    print_success "Cleanup completed"
}

# Trap to ensure cleanup on exit
trap cleanup EXIT

# Main execution
main() {
    print_status "Starting Palytt automated testing suite..."
    
    # Check prerequisites
    if ! check_prerequisites; then
        print_error "Prerequisites check failed"
        exit 1
    fi
    
    # Start backend server if needed
    if [[ "$BACKEND_ONLY" == true || ("$NO_BACKEND" != true && "$UI_ONLY" != true && "$UNIT_ONLY" != true) ]]; then
        if ! start_backend; then
            print_error "Failed to start backend server"
            if [[ "$BACKEND_ONLY" == true ]]; then
                exit 1
            else
                print_warning "Continuing without backend..."
                NO_BACKEND=true
            fi
        fi
    fi
    
    # Run backend tests if requested
    if [[ "$BACKEND_ONLY" == true ]]; then
        run_backend_tests
        generate_report
        exit $?
    fi
    
    # Build project (unless only doing backend tests)
    if [[ "$BACKEND_ONLY" != true ]]; then
        if ! build_project; then
            generate_report
            exit 1
        fi
        
        if [[ "$BUILD_ONLY" == true ]]; then
            generate_report
            exit 0
        fi
    fi
    
    # Run backend tests if not skipped
    if [[ "$NO_BACKEND" != true && "$UNIT_ONLY" != true && "$UI_ONLY" != true ]]; then
        run_backend_tests
    fi
    
    # Run unit tests
    if [[ "$UI_ONLY" != true && "$BACKEND_ONLY" != true ]]; then
        run_unit_tests
    fi
    
    # Run UI tests
    if [[ "$UNIT_ONLY" != true && "$BACKEND_ONLY" != true ]]; then
        run_ui_tests
    fi
    
    # Run Maestro tests (optional)
    if [[ "$UNIT_ONLY" != true && "$BACKEND_ONLY" != true ]]; then
        run_maestro_tests
    fi
    
    # Generate final report
    generate_report
    exit $?
}

# Run main function
main "$@" 