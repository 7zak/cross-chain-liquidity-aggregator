#!/bin/bash

# Cross-Chain Liquidity Aggregator Setup Script
# This script sets up the development environment

set -e

echo "🚀 Setting up Cross-Chain Liquidity Aggregator development environment..."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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

# Check if running on supported OS
check_os() {
    print_status "Checking operating system..."
    
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        OS="linux"
        print_success "Linux detected"
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        OS="macos"
        print_success "macOS detected"
    else
        print_error "Unsupported operating system: $OSTYPE"
        exit 1
    fi
}

# Check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Install Rust and Cargo (required for Clarinet)
install_rust() {
    if command_exists rustc; then
        print_success "Rust is already installed"
        rustc --version
    else
        print_status "Installing Rust..."
        curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
        source ~/.cargo/env
        print_success "Rust installed successfully"
    fi
}

# Install Clarinet
install_clarinet() {
    if command_exists clarinet; then
        print_success "Clarinet is already installed"
        clarinet --version
    else
        print_status "Installing Clarinet..."
        cargo install clarinet-cli
        print_success "Clarinet installed successfully"
    fi
}

# Install Node.js dependencies
install_node_deps() {
    if command_exists node; then
        print_success "Node.js is already installed"
        node --version
    else
        print_warning "Node.js not found. Please install Node.js 16+ from https://nodejs.org/"
        exit 1
    fi
    
    if command_exists npm; then
        print_status "Installing Node.js dependencies..."
        npm install
        print_success "Node.js dependencies installed"
    else
        print_error "npm not found. Please install Node.js with npm"
        exit 1
    fi
}

# Verify Clarinet setup
verify_clarinet() {
    print_status "Verifying Clarinet setup..."
    
    if clarinet check; then
        print_success "Contract syntax check passed"
    else
        print_error "Contract syntax check failed"
        exit 1
    fi
}

# Run tests
run_tests() {
    print_status "Running tests..."
    
    if clarinet test; then
        print_success "All tests passed"
    else
        print_warning "Some tests failed. Please review the output above."
    fi
}

# Create development directories
setup_directories() {
    print_status "Setting up development directories..."
    
    mkdir -p deployments
    mkdir -p logs
    mkdir -p .local
    
    print_success "Development directories created"
}

# Setup Git hooks (optional)
setup_git_hooks() {
    print_status "Setting up Git hooks..."
    
    # Pre-commit hook
    cat > .git/hooks/pre-commit << 'EOF'
#!/bin/bash
echo "Running pre-commit checks..."

# Check contract syntax
if ! clarinet check; then
    echo "❌ Contract syntax check failed"
    exit 1
fi

# Run tests
if ! clarinet test; then
    echo "❌ Tests failed"
    exit 1
fi

echo "✅ Pre-commit checks passed"
EOF

    chmod +x .git/hooks/pre-commit
    print_success "Git hooks configured"
}

# Main setup function
main() {
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║          Cross-Chain Liquidity Aggregator Setup             ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo ""
    
    check_os
    install_rust
    install_clarinet
    install_node_deps
    setup_directories
    verify_clarinet
    run_tests
    setup_git_hooks
    
    echo ""
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║                    Setup Complete! 🎉                       ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo ""
    print_success "Development environment is ready!"
    echo ""
    echo "📚 Next steps:"
    echo "  1. Review the README.md for project overview"
    echo "  2. Check docs/ directory for detailed documentation"
    echo "  3. Run 'clarinet console' to interact with contracts"
    echo "  4. Use 'npm run dev' to start development mode"
    echo ""
    echo "🔗 Useful commands:"
    echo "  clarinet check          - Check contract syntax"
    echo "  clarinet test           - Run tests"
    echo "  clarinet console        - Interactive console"
    echo "  clarinet integrate      - Start local blockchain"
    echo "  npm run deploy:testnet  - Deploy to testnet"
    echo ""
    echo "📖 Documentation:"
    echo "  README.md               - Project overview"
    echo "  docs/API.md             - API documentation"
    echo "  docs/INTEGRATION.md     - Integration guide"
    echo "  docs/ARCHITECTURE.md    - Architecture overview"
    echo "  CONTRIBUTING.md         - Contribution guidelines"
    echo ""
}

# Run main function
main "$@"
