#!/bin/bash
# FairCoder Environment Setup Script for Unix-based systems (Linux/MacOS)
# This script automates the setup process for the FairCoder project
# It will check prerequisites, install required software, and verify the installation

# Function to print section headers
print_section_header() {
    echo -e "\n\033[1;36m===== $1 =====\033[0m"
}

# Function to print success messages
print_success() {
    echo -e "\033[1;32m[SUCCESS] $1\033[0m"
}

# Function to print error messages
print_error() {
    echo -e "\033[1;31m[ERROR] $1\033[0m"
}

# Function to print info messages
print_info() {
    echo -e "\033[1;33m[INFO] $1\033[0m"
}

# Function to check if a command exists
command_exists() {
    command -v "$1" &> /dev/null
}

# Check operating system
print_section_header "Checking Operating System"
OS="$(uname)"
if [ "$OS" = "Linux" ]; then
    print_success "Running on Linux"
    
    # Check if we're running on a Debian-based system (Ubuntu, Debian, etc.)
    if command_exists apt-get; then
        PACKAGE_MANAGER="apt-get"
        INSTALL_CMD="sudo apt-get install -y"
    # Check if we're running on a Red Hat-based system (Fedora, RHEL, CentOS)
    elif command_exists dnf; then
        PACKAGE_MANAGER="dnf"
        INSTALL_CMD="sudo dnf install -y"
    elif command_exists yum; then
        PACKAGE_MANAGER="yum"
        INSTALL_CMD="sudo yum install -y"
    # Check for Arch Linux
    elif command_exists pacman; then
        PACKAGE_MANAGER="pacman"
        INSTALL_CMD="sudo pacman -S --noconfirm"
    else
        print_error "Unsupported Linux distribution. Package manager not identified."
        exit 1
    fi
elif [ "$OS" = "Darwin" ]; then
    print_success "Running on macOS"
    
    # Check if Homebrew is installed
    if ! command_exists brew; then
        print_info "Homebrew not found. Installing Homebrew..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        if [ $? -ne 0 ]; then
            print_error "Failed to install Homebrew. Please install manually."
            exit 1
        fi
        print_success "Homebrew installed successfully"
    else
        print_success "Homebrew is already installed"
    fi
    
    PACKAGE_MANAGER="brew"
    INSTALL_CMD="brew install"
else
    print_error "Unsupported operating system: $OS"
    exit 1
fi

# Check for Python installation
print_section_header "Checking Python Installation"
if command_exists python3; then
    PYTHON_CMD="python3"
    PYTHON_VERSION=$(python3 --version)
    print_success "Python is installed: $PYTHON_VERSION"
else
    print_info "Python 3 not found. Installing..."
    
    if [ "$PACKAGE_MANAGER" = "apt-get" ]; then
        sudo apt-get update
        $INSTALL_CMD python3 python3-pip python3-venv
    elif [ "$PACKAGE_MANAGER" = "dnf" ] || [ "$PACKAGE_MANAGER" = "yum" ]; then
        $INSTALL_CMD python3 python3-pip
    elif [ "$PACKAGE_MANAGER" = "pacman" ]; then
        $INSTALL_CMD python python-pip
    elif [ "$PACKAGE_MANAGER" = "brew" ]; then
        $INSTALL_CMD python
    fi
    
    if [ $? -ne 0 ]; then
        print_error "Failed to install Python. Please install manually."
        exit 1
    fi
    
    # Check Python installation again
    if command_exists python3; then
        PYTHON_CMD="python3"
        PYTHON_VERSION=$(python3 --version)
        print_success "Python is now installed: $PYTHON_VERSION"
    else
        print_error "Python installation failed. Please install Python 3 manually."
        exit 1
    fi
fi

# Check for pip
print_section_header "Checking pip Installation"
if command_exists pip3; then
    PIP_CMD="pip3"
    PIP_VERSION=$(pip3 --version)
    print_success "pip is installed: $PIP_VERSION"
elif command_exists pip; then
    PIP_CMD="pip"
    PIP_VERSION=$(pip --version)
    print_success "pip is installed: $PIP_VERSION"
else
    print_info "pip not found. Installing..."
    
    if [ "$OS" = "Linux" ]; then
        if [ "$PACKAGE_MANAGER" = "apt-get" ]; then
            $INSTALL_CMD python3-pip
        elif [ "$PACKAGE_MANAGER" = "dnf" ] || [ "$PACKAGE_MANAGER" = "yum" ]; then
            $INSTALL_CMD python3-pip
        elif [ "$PACKAGE_MANAGER" = "pacman" ]; then
            $INSTALL_CMD python-pip
        fi
    elif [ "$OS" = "Darwin" ]; then
        $PYTHON_CMD -m ensurepip --upgrade
    fi
    
    if command_exists pip3; then
        PIP_CMD="pip3"
    elif command_exists pip; then
        PIP_CMD="pip"
    else
        print_error "Failed to install pip. Please install manually."
        exit 1
    fi
    
    print_success "pip is now installed"
fi

# Create virtual environment
print_section_header "Setting up Python Virtual Environment"
if [ -d ".myenv" ]; then
    print_info "Virtual environment already exists. Skipping creation."
else
    print_info "Creating virtual environment..."
    $PYTHON_CMD -m venv .myenv
    
    if [ $? -ne 0 ]; then
        print_error "Failed to create virtual environment. Please check if python3-venv is installed."
        if [ "$PACKAGE_MANAGER" = "apt-get" ]; then
            print_info "Trying to install python3-venv..."
            $INSTALL_CMD python3-venv
            $PYTHON_CMD -m venv .myenv
            
            if [ $? -ne 0 ]; then
                print_error "Failed to create virtual environment despite installing python3-venv."
                exit 1
            fi
        else
            exit 1
        fi
    fi
    
    print_success "Virtual environment created successfully"
fi

# Activate virtual environment
print_info "Activating virtual environment..."
source .myenv/bin/activate

if [ $? -ne 0 ]; then
    print_error "Failed to activate virtual environment."
    exit 1
fi

print_success "Virtual environment activated"

# Check for NVIDIA GPU (Linux only)
if [ "$OS" = "Linux" ]; then
    print_section_header "Checking for NVIDIA GPU"
    if command_exists nvidia-smi; then
        NVIDIA_SMI_OUTPUT=$(nvidia-smi)
        print_success "NVIDIA GPU detected"
        echo "$NVIDIA_SMI_OUTPUT"
        HAS_NVIDIA_GPU=true
    else
        print_info "nvidia-smi command not found. No NVIDIA GPU detected or drivers not installed."
        HAS_NVIDIA_GPU=false
    fi
else
    # For macOS, assume no NVIDIA GPU
    print_section_header "Checking for NVIDIA GPU"
    print_info "NVIDIA GPUs are not supported on macOS. Using CPU version."
    HAS_NVIDIA_GPU=false
fi

# Install PyTorch
print_section_header "Installing PyTorch"
if [ "$HAS_NVIDIA_GPU" = true ]; then
    print_info "Installing PyTorch with CUDA support..."
    $PIP_CMD install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu121
else
    print_info "Installing PyTorch CPU version..."
    $PIP_CMD install torch torchvision torchaudio
fi

# Test PyTorch installation
print_info "Testing PyTorch installation..."
if [ "$HAS_NVIDIA_GPU" = true ]; then
    TORCH_TEST=$($PYTHON_CMD -c "import torch; print('CUDA available:', torch.cuda.is_available()); print(torch.rand(2,3).cuda() if torch.cuda.is_available() else 'CUDA not available')")
else
    TORCH_TEST=$($PYTHON_CMD -c "import torch; print('CPU Tensor:'); print(torch.rand(2,3))")
fi

echo "$TORCH_TEST"
print_success "PyTorch installation verified"

# Install required packages
print_section_header "Installing Required Python Packages"
PACKAGES=("openai" "numpy" "pandas")
for package in "${PACKAGES[@]}"; do
    print_info "Installing $package..."
    $PIP_CMD install $package
    
    if [ $? -eq 0 ]; then
        print_success "$package installed successfully"
    else
        print_error "Failed to install $package"
    fi
done

# Install Git if not already installed
print_section_header "Checking Git Installation"
if command_exists git; then
    GIT_VERSION=$(git --version)
    print_success "Git is already installed: $GIT_VERSION"
else
    print_info "Git not found. Installing..."
    
    if [ "$OS" = "Linux" ]; then
        $INSTALL_CMD git
    elif [ "$OS" = "Darwin" ]; then
        $INSTALL_CMD git
    fi
    
    if command_exists git; then
        GIT_VERSION=$(git --version)
        print_success "Git is now installed: $GIT_VERSION"
    else
        print_error "Failed to install Git. Please install manually."
        exit 1
    fi
fi

# Setup Hugging Face Transformers
print_section_header "Setting up Hugging Face Transformers"
print_info "Installing Transformers library..."
if [ "$HAS_NVIDIA_GPU" = true ]; then
    $PIP_CMD install transformers
else
    $PIP_CMD install 'transformers[torch]'
fi

if [ $? -eq 0 ]; then
    print_success "Transformers library installed successfully"
else
    print_error "Failed to install Transformers library"
fi

# Install Hugging Face Hub CLI
print_info "Installing Hugging Face Hub CLI..."
$PIP_CMD install huggingface_hub

if [ $? -eq 0 ]; then
    print_success "Hugging Face Hub CLI installed successfully"
    print_info "To login to Hugging Face, run: huggingface-cli login"
    print_info "You will need to create an account on huggingface.co and generate a token"
else
    print_error "Failed to install Hugging Face Hub CLI"
fi

# Ask if user wants to set up GitHub repository
print_section_header "GitHub Repository Setup"
read -p "Do you want to set up the FairCoder GitHub repository? (y/n) " SETUP_GITHUB

if [ "$SETUP_GITHUB" = "y" ] || [ "$SETUP_GITHUB" = "Y" ]; then
    read -p "Enter your GitHub username: " GITHUB_USERNAME
    read -p "Enter local path for repository (or press Enter for current directory): " REPO_PATH
    
    if [ -z "$REPO_PATH" ]; then
        REPO_PATH="./FairCoder"
    fi
    
    print_info "Forking and cloning AI-Plans/FairCoder repository..."
    print_info "Please create a fork of https://github.com/AI-Plans/FairCoder in your GitHub account"
    read -p "Press Enter once you've created the fork... " -n1 -s
    echo ""
    
    # Clone the forked repository
    git clone "https://github.com/$GITHUB_USERNAME/FairCoder.git" "$REPO_PATH"
    
    if [ $? -eq 0 ]; then
        print_success "Repository cloned successfully to $REPO_PATH"
    else
        print_error "Failed to clone repository"
    fi
else
    print_info "Skipping GitHub repository setup"
fi

# Final verification
print_section_header "Environment Setup Complete"
print_success "FairCoder environment has been set up successfully"
print_info "Python: $($PYTHON_CMD --version)"
print_info "PyTorch: $($PYTHON_CMD -c "import torch; print(torch.__version__)")"
print_info "Transformers: $($PYTHON_CMD -c "import transformers; print(transformers.__version__)")"

# Remind about OpenAI API setup
print_section_header "Additional Steps"
print_info "OpenAI API Setup was not covered in this script. Please refer to documentation for setup instructions."
print_info "To request access to gated model repositories, visit:"
print_info "  - https://huggingface.co/meta-llama/Llama-2-7b-hf"
print_info "  - https://huggingface.co/meta-llama/Meta-Llama-3-8B-Instruct"
print_info "  - https://huggingface.co/mistralai/Mistral-7B-Instruct-v0.2"
print_info "  - https://huggingface.co/google/codegemma-7b-it"
print_info "  - https://huggingface.co/unsloth/llama-3-8b-Instruct (alternative)"

# Instructions for deactivating virtual environment
print_info "To deactivate the virtual environment when done, run: deactivate"