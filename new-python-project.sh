#!/bin/bash

# new-python-project.sh
# A comprehensive Python project generator following modern best practices (2024/2025)
# Author: GitHub Copilot
# Version: 1.0.0

set -euo pipefail  # Exit on error, undefined vars, and pipe failures

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
DEFAULT_PYTHON_VERSION="3.11"
DEFAULT_LICENSE="MIT"

# Global variables
PROJECT_NAME=""
PROJECT_DESCRIPTION=""
AUTHOR_NAME=""
AUTHOR_EMAIL=""
PYTHON_VERSION="$DEFAULT_PYTHON_VERSION"
LICENSE_TYPE="$DEFAULT_LICENSE"
ADDITIONAL_DEPS=""
FORCE_OVERWRITE=false
DRY_RUN=false
VERBOSE=false

# Function to print colored output
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

# Help function
show_help() {
    cat << EOF
Usage: $0 [OPTIONS] PROJECT_NAME

Create a new Python project with modern best practices structure.

ARGUMENTS:
    PROJECT_NAME        Name of the project (required)

OPTIONS:
    -d, --description   Project description
    -a, --author        Author name
    -e, --email         Author email
    -p, --python        Python version (default: $DEFAULT_PYTHON_VERSION)
    -l, --license       License type (default: $DEFAULT_LICENSE)
    --deps              Additional dependencies (comma-separated)
    -f, --force         Force overwrite existing directory
    --dry-run           Print what would be done without executing
    --verbose           Enable verbose output (set -x)
    -h, --help          Show this help message

EXAMPLES:
    $0 my_awesome_project
    $0 -d "My awesome Python app" -a "John Doe" -e "john@example.com" my_project
    $0 --python 3.12 --license Apache-2.0 --deps "requests,fastapi" my_api

SUPPORTED LICENSES:
    MIT, Apache-2.0, GPL-3.0, BSD-3-Clause, BSD-2-Clause

EOF
}

# Parse command line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            -d|--description)
                PROJECT_DESCRIPTION="$2"
                shift 2
                ;;
            -a|--author)
                AUTHOR_NAME="$2"
                shift 2
                ;;
            -e|--email)
                AUTHOR_EMAIL="$2"
                shift 2
                ;;
            -p|--python)
                PYTHON_VERSION="$2"
                shift 2
                ;;
            -l|--license)
                LICENSE_TYPE="$2"
                shift 2
                ;;
            --deps)
                ADDITIONAL_DEPS="$2"
                shift 2
                ;;
            -f|--force)
                FORCE_OVERWRITE=true
                shift
                ;;
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            --verbose)
                VERBOSE=true
                shift
                ;;
            -*)
                print_error "Unknown option: $1"
                show_help
                exit 1
                ;;
            *)
                if [[ -z "$PROJECT_NAME" ]]; then
                    PROJECT_NAME="$1"
                else
                    print_error "Multiple project names provided. Use only one."
                    exit 1
                fi
                shift
                ;;
        esac
    done

    # Validate required arguments
    if [[ -z "$PROJECT_NAME" ]]; then
        print_error "Project name is required."
        show_help
        exit 1
    fi
}

# Validate project name
validate_project_name() {
    if [[ ! "$PROJECT_NAME" =~ ^[a-zA-Z][a-zA-Z0-9_]*$ ]]; then
        print_error "Invalid project name. Must start with a letter and contain only letters, numbers, and underscores."
        exit 1
    fi
}

# Check if required tools are installed
check_dependencies() {
    local missing_deps=()
    
    if ! command -v python3 &> /dev/null; then
        missing_deps+=("python3")
    fi
    
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        print_error "Missing required dependencies: ${missing_deps[*]}"
        print_info "Please install the missing dependencies and try again."
        exit 1
    fi
    
    # Check for git (optional but recommended)
    if ! command -v git &> /dev/null; then
        print_warning "Git is not available. Git repository initialization will be skipped."
        print_info "Install git to enable version control features."
    fi
}

# Validate Python version
validate_python_version() {
    if ! python3 -c "
import sys
version = tuple(map(int, sys.version.split()[0].split('.')))
required = tuple(map(int, '$PYTHON_VERSION'.split('.')))
if version < required:
    print(f'Python {sys.version.split()[0]} is installed, but {\"$PYTHON_VERSION\"} or higher is required.')
    exit(1)
print(f'Python {sys.version.split()[0]} is available.')
" 2>/dev/null; then
        print_error "Python $PYTHON_VERSION or higher is required."
        exit 1
    fi
}

# Check if directory exists and handle accordingly
check_directory() {
    if [[ -d "$PROJECT_NAME" ]]; then
        if [[ "$FORCE_OVERWRITE" == false ]]; then
            print_error "Directory '$PROJECT_NAME' already exists. Use -f/--force to overwrite."
            exit 1
        else
            local backup="${PROJECT_NAME}.bak.$(date +%Y%m%d_%H%M%S)"
            print_warning "Backing up existing directory '$PROJECT_NAME' to '$backup'..."
            mv "$PROJECT_NAME" "$backup"
        fi
    fi
}

# Get author information from git if not provided, falling back to hardcoded defaults
get_author_info() {
    if [[ -z "$AUTHOR_NAME" ]]; then
        AUTHOR_NAME=$(git config user.name 2>/dev/null || echo "")
    fi

    if [[ -z "$AUTHOR_EMAIL" ]]; then
        AUTHOR_EMAIL=$(git config user.email 2>/dev/null || echo "")
    fi

    if [[ -z "$AUTHOR_NAME" ]]; then
        AUTHOR_NAME="Rich.Taft"
    fi

    if [[ -z "$AUTHOR_EMAIL" ]]; then
        AUTHOR_EMAIL="Rich8449@gmail.com"
    fi
}

# Main function to orchestrate project creation
main() {
    parse_args "$@"

    [[ "$VERBOSE" == true ]] && set -x

    validate_project_name
    check_dependencies
    validate_python_version
    get_author_info

    if [[ "$DRY_RUN" == true ]]; then
        print_info "Dry run — no files will be created."
        echo "  Project name:    $PROJECT_NAME"
        echo "  Description:     ${PROJECT_DESCRIPTION:-(none)}"
        echo "  Author:          $AUTHOR_NAME <$AUTHOR_EMAIL>"
        echo "  Python version:  $PYTHON_VERSION"
        echo "  License:         $LICENSE_TYPE"
        echo "  Extra deps:      ${ADDITIONAL_DEPS:-(none)}"
        echo "  Force overwrite: $FORCE_OVERWRITE"
        echo ""
        echo "  Steps that would run:"
        echo "    1. Create directory: $PROJECT_NAME/"
        echo "    2. Generate project structure and configuration files"
        echo "    3. Generate Python boilerplate (src/$PROJECT_NAME/, tests/)"
        echo "    4. Set up virtual environment and install dependencies"
        echo "    5. Generate documentation (README.md, LICENSE, docs/)"
        echo "    6. Initialize git repository with initial commit"
        echo "    7. Install pre-commit hooks"
        return 0
    fi

    print_info "Starting Python project creation: $PROJECT_NAME"
    check_directory
    print_info "Creating project structure..."

    # Create project directory
    mkdir -p "$PROJECT_NAME"
    cd "$PROJECT_NAME"
    
    # Initialize project
    create_directory_structure
    create_configuration_files
    create_python_files
    setup_virtual_environment || print_warning "Virtual environment setup had issues but continuing..."
    create_documentation
    initialize_git_repository || print_warning "Git repository setup had issues but continuing..."
    setup_precommit_hooks || print_warning "Pre-commit setup had issues but continuing..."
    
    print_success "Project '$PROJECT_NAME' created successfully!"
    print_info "Next steps:"
    echo "  1. cd $PROJECT_NAME"
    echo "  2. source venv/bin/activate"
    echo "  3. pip install -e ."
    echo "  4. python src/$PROJECT_NAME/main.py --help"
}

# Create the directory structure
create_directory_structure() {
    print_info "Creating directory structure..."
    
    # Create main directories
    mkdir -p src/"$PROJECT_NAME"
    mkdir -p tests
    mkdir -p docs
    mkdir -p config
    mkdir -p scripts
    
    # Create __init__.py files
    touch src/"$PROJECT_NAME"/__init__.py
    touch tests/__init__.py
}

# Create configuration files
create_configuration_files() {
    print_info "Creating configuration files..."
    
    # Create pyproject.toml
    cat > pyproject.toml << EOF
[build-system]
requires = ["hatchling"]
build-backend = "hatchling.build"

[project]
name = "$PROJECT_NAME"
dynamic = ["version"]
description = "${PROJECT_DESCRIPTION:-A Python project}"
readme = "README.md"
license = {text = "$LICENSE_TYPE"}
requires-python = ">=$PYTHON_VERSION"
authors = [
    {name = "$AUTHOR_NAME", email = "$AUTHOR_EMAIL"},
]
keywords = ["python"]
classifiers = [
    "Development Status :: 3 - Alpha",
    "Intended Audience :: Developers",
    "Programming Language :: Python :: 3",
    "Programming Language :: Python :: $PYTHON_VERSION",
]
dependencies = []

[project.optional-dependencies]
dev = [
    "pytest>=7.0",
    "pytest-cov>=4.0",
    "black>=23.0",
    "isort>=5.0",
    "flake8>=6.0",
    "mypy>=1.0",
    "ruff>=0.1.0",
    "pre-commit>=3.0",
]

[project.urls]
Homepage = "https://github.com/$AUTHOR_NAME/$PROJECT_NAME"
Repository = "https://github.com/$AUTHOR_NAME/$PROJECT_NAME.git"
Issues = "https://github.com/$AUTHOR_NAME/$PROJECT_NAME/issues"

[project.scripts]
$PROJECT_NAME = "$PROJECT_NAME.main:main"

[tool.hatch.version]
path = "src/$PROJECT_NAME/__init__.py"

[tool.black]
line-length = 88
target-version = ['py$(echo $PYTHON_VERSION | tr -d .)']
include = '\.pyi?$'

[tool.isort]
profile = "black"
multi_line_output = 3

[tool.mypy]
python_version = "$PYTHON_VERSION"
strict = true
warn_return_any = true
warn_unused_configs = true

[tool.pytest.ini_options]
minversion = "7.0"
addopts = "-ra -q --cov=src"
testpaths = ["tests"]

[tool.coverage.run]
source = ["src"]

[tool.coverage.report]
exclude_lines = [
    "pragma: no cover",
    "def __repr__",
    "raise AssertionError",
    "raise NotImplementedError",
]
EOF

    # Create requirements.txt
    cat > requirements.txt << EOF
# Production dependencies
# Add your project dependencies here
EOF

    # Create requirements-dev.txt
    cat > requirements-dev.txt << EOF
# Development dependencies
pytest>=7.0
pytest-cov>=4.0
black>=23.0
isort>=5.0
flake8>=6.0
mypy>=1.0
pre-commit>=3.0
ruff>=0.1.0
EOF

    # Add additional dependencies if provided
    if [[ -n "$ADDITIONAL_DEPS" ]]; then
        IFS=',' read -ra DEPS <<< "$ADDITIONAL_DEPS"
        for dep in "${DEPS[@]}"; do
            echo "$dep" >> requirements.txt
        done
    fi

    # Create .gitignore
    cat > .gitignore << 'EOF'
# Byte-compiled / optimized / DLL files
__pycache__/
*.py[cod]
*$py.class

# C extensions
*.so

# Distribution / packaging
.Python
build/
develop-eggs/
dist/
downloads/
eggs/
.eggs/
lib/
lib64/
parts/
sdist/
var/
wheels/
share/python-wheels/
*.egg-info/
.installed.cfg
*.egg
MANIFEST

# PyInstaller
*.manifest
*.spec

# Installer logs
pip-log.txt
pip-delete-this-directory.txt

# Unit test / coverage reports
htmlcov/
.tox/
.nox/
.coverage
.coverage.*
.cache
nosetests.xml
coverage.xml
*.cover
*.py,cover
.hypothesis/
.pytest_cache/
cover/

# Translations
*.mo
*.pot

# Django stuff:
*.log
local_settings.py
db.sqlite3
db.sqlite3-journal

# Flask stuff:
instance/
.webassets-cache

# Scrapy stuff:
.scrapy

# Sphinx documentation
docs/_build/

# PyBuilder
.pybuilder/
target/

# Jupyter Notebook
.ipynb_checkpoints

# IPython
profile_default/
ipython_config.py

# pyenv
.python-version

# pipenv
Pipfile.lock

# poetry
poetry.lock

# pdm
.pdm.toml

# PEP 582
__pypackages__/

# Celery stuff
celerybeat-schedule
celerybeat.pid

# SageMath parsed files
*.sage.py

# Environments
.env
.venv
env/
venv/
ENV/
env.bak/
venv.bak/

# Spyder project settings
.spyderproject
.spyproject

# Rope project settings
.ropeproject

# mkdocs documentation
/site

# mypy
.mypy_cache/
.dmypy.json
dmypy.json

# Pyre type checker
.pyre/

# pytype static type analyzer
.pytype/

# Cython debug symbols
cython_debug/

# PyCharm
.idea/

# VSCode
.vscode/

# macOS
.DS_Store

# Windows
Thumbs.db
ehthumbs.db
Desktop.ini
EOF

    # Create .editorconfig
    cat > .editorconfig << 'EOF'
# EditorConfig is awesome: https://EditorConfig.org

# top-most EditorConfig file
root = true

[*]
indent_style = space
indent_size = 4
end_of_line = lf
charset = utf-8
trim_trailing_whitespace = true
insert_final_newline = true

[*.{yml,yaml}]
indent_size = 2

[*.md]
trim_trailing_whitespace = false

[Makefile]
indent_style = tab
EOF

    # Create .gitattributes
    cat > .gitattributes << 'EOF'
# Set default behavior to automatically normalize line endings.
* text=auto

# Force batch scripts to always use CRLF line endings so that if a repo is accessed
# in Windows via a file share from Linux, the scripts will work.
*.{cmd,[cC][mM][dD]} text eol=crlf
*.{bat,[bB][aA][tT]} text eol=crlf

# Force bash scripts to always use LF line endings so that if a repo is accessed
# in Windows, the scripts will work.
*.sh text eol=lf

# Python files
*.py text diff=python

# These files are text and should be normalized (Convert crlf => lf)
*.css text
*.df text
*.htm text
*.html text
*.java text
*.js text
*.json text
*.jsp text
*.jspf text
*.jspx text
*.properties text
*.sh text
*.tld text
*.txt text
*.tag text
*.tagx text
*.xml text

# These files are binary and should be left untouched
# (binary is a macro for -text -diff)
*.class binary
*.dll binary
*.ear binary
*.gif binary
*.ico binary
*.jar binary
*.jpg binary
*.jpeg binary
*.png binary
*.so binary
*.war binary
EOF

    # Create pre-commit configuration
    cat > .pre-commit-config.yaml << EOF
# See https://pre-commit.com for more information
repos:
  - repo: https://github.com/pre-commit/pre-commit-hooks
    rev: v4.5.0
    hooks:
      - id: trailing-whitespace
      - id: end-of-file-fixer
      - id: check-yaml
      - id: check-added-large-files
      - id: check-case-conflict
      - id: check-merge-conflict
      - id: debug-statements
      - id: check-toml

  - repo: https://github.com/psf/black
    rev: 23.12.1
    hooks:
      - id: black
        language_version: python3

  - repo: https://github.com/pycqa/isort
    rev: 5.13.2
    hooks:
      - id: isort
        args: ["--profile", "black"]

  - repo: https://github.com/pycqa/flake8
    rev: 7.0.0
    hooks:
      - id: flake8
        args: [--max-line-length=88, --extend-ignore=E203]

  - repo: https://github.com/pre-commit/mirrors-mypy
    rev: v1.8.0
    hooks:
      - id: mypy
        additional_dependencies: [types-all]
        args: [--strict]

  - repo: https://github.com/charliermarsh/ruff-pre-commit
    rev: v0.1.9
    hooks:
      - id: ruff
        args: [--fix, --exit-non-zero-on-fix]
EOF
}

# Create Python files
create_python_files() {
    print_info "Creating Python boilerplate files..."
    
    # Create main __init__.py with version
    cat > src/"$PROJECT_NAME"/__init__.py << EOF
"""$PROJECT_NAME package.

${PROJECT_DESCRIPTION:-A Python project}
"""

__version__ = "0.1.0"
__author__ = "$AUTHOR_NAME"
__email__ = "$AUTHOR_EMAIL"

__all__ = ["main"]

from .main import main
EOF

    # Create main.py with argparse CLI
    cat > src/"$PROJECT_NAME"/main.py << EOF
"""Main module for $PROJECT_NAME.

This module provides the command-line interface for the application.
"""

import argparse
import logging
import sys
from typing import List, Optional

from . import __version__


def setup_logging(verbose: bool = False) -> None:
    """Set up logging configuration.
    
    Args:
        verbose: If True, set log level to DEBUG, otherwise INFO.
    """
    log_level = logging.DEBUG if verbose else logging.INFO
    logging.basicConfig(
        level=log_level,
        format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
    )


def create_parser() -> argparse.ArgumentParser:
    """Create and configure the argument parser.
    
    Returns:
        Configured ArgumentParser instance.
    """
    parser = argparse.ArgumentParser(
        description="${PROJECT_DESCRIPTION:-A Python project}",
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    
    parser.add_argument(
        "--version",
        action="version",
        version=f"$PROJECT_NAME {__version__}",
    )
    
    parser.add_argument(
        "-v", "--verbose",
        action="store_true",
        help="Enable verbose output",
    )
    
    # Add your command-line arguments here
    parser.add_argument(
        "input",
        nargs="?",
        help="Input file or argument",
    )
    
    return parser


def run_application(args: argparse.Namespace) -> int:
    """Run the main application logic.
    
    Args:
        args: Parsed command-line arguments.
        
    Returns:
        Exit code (0 for success, non-zero for error).
    """
    logger = logging.getLogger(__name__)
    
    try:
        logger.info("Starting $PROJECT_NAME application")
        
        # Your main application logic goes here
        if args.input:
            logger.info(f"Processing input: {args.input}")
        else:
            logger.info("No input provided, running with defaults")
        
        # Example placeholder logic
        print(f"Hello from $PROJECT_NAME!")
        if args.input:
            print(f"Input received: {args.input}")
        
        logger.info("Application completed successfully")
        return 0
        
    except Exception as e:
        logger.error(f"Application error: {e}")
        if args.verbose:
            logger.exception("Full traceback:")
        return 1


def main(argv: Optional[List[str]] = None) -> int:
    """Main entry point for the application.
    
    Args:
        argv: Command-line arguments (defaults to sys.argv).
        
    Returns:
        Exit code.
    """
    parser = create_parser()
    args = parser.parse_args(argv)
    
    setup_logging(args.verbose)
    
    return run_application(args)


if __name__ == "__main__":
    sys.exit(main())
EOF

    # Create a sample test file
    cat > tests/test_main.py << EOF
"""Tests for the main module."""

import pytest
from unittest.mock import patch
import sys
from io import StringIO

from $PROJECT_NAME.main import main, create_parser, run_application


class TestMain:
    """Test cases for main functionality."""
    
    def test_create_parser(self):
        """Test parser creation."""
        parser = create_parser()
        assert parser is not None
        
        # Test help doesn't raise an exception
        with pytest.raises(SystemExit):
            parser.parse_args(["--help"])
    
    def test_version_argument(self):
        """Test version argument."""
        parser = create_parser()
        
        with pytest.raises(SystemExit):
            parser.parse_args(["--version"])
    
    def test_main_with_input(self):
        """Test main function with input."""
        with patch('sys.stdout', new_callable=StringIO) as mock_stdout:
            result = main(["test_input"])
            
        assert result == 0
        output = mock_stdout.getvalue()
        assert "Hello from $PROJECT_NAME!" in output
        assert "test_input" in output
    
    def test_main_without_input(self):
        """Test main function without input."""
        with patch('sys.stdout', new_callable=StringIO) as mock_stdout:
            result = main([])
            
        assert result == 0
        output = mock_stdout.getvalue()
        assert "Hello from $PROJECT_NAME!" in output
    
    def test_verbose_flag(self):
        """Test verbose flag."""
        result = main(["--verbose"])
        assert result == 0


if __name__ == "__main__":
    pytest.main([__file__])
EOF

    # Create conftest.py for pytest configuration
    cat > tests/conftest.py << EOF
"""Pytest configuration and fixtures."""

import pytest
import logging


@pytest.fixture(autouse=True)
def setup_test_logging():
    """Set up logging for tests."""
    logging.basicConfig(level=logging.DEBUG)


# Add your test fixtures here
@pytest.fixture
def sample_data():
    """Provide sample test data."""
    return {"test": "data"}
EOF
}

# Set up virtual environment and install dependencies
setup_virtual_environment() {
    print_info "Setting up virtual environment..."
    
    # Create virtual environment
    if ! python3 -m venv venv 2>/dev/null; then
        print_warning "Failed to create virtual environment."
        print_info "On Debian/Ubuntu systems, you may need to install: apt install python3-venv"
        print_info "On other systems, ensure the venv module is available."
        print_info "Skipping virtual environment setup. You can create it manually later with:"
        print_info "  python3 -m venv venv"
        print_info "  source venv/bin/activate"
        print_info "  pip install -r requirements-dev.txt"
        print_info "  pip install -e ."
        return 1
    fi
    
    # Activate virtual environment and install dependencies
    source venv/bin/activate
    
    # Upgrade pip
    if ! pip install --upgrade pip; then
        print_warning "Failed to upgrade pip"
    fi
    
    # Install development dependencies
    if ! pip install -r requirements-dev.txt; then
        print_warning "Failed to install development dependencies"
        print_info "You can install them manually later with: pip install -r requirements-dev.txt"
    fi
    
    # Install project in development mode
    if ! pip install -e .; then
        print_warning "Failed to install project in development mode"
        print_info "You can install it manually later with: pip install -e ."
    fi
    
    print_success "Virtual environment setup completed"
}

# Create documentation
create_documentation() {
    print_info "Creating documentation..."
    
    # Create comprehensive README.md
    cat > README.md << EOF
# $PROJECT_NAME

${PROJECT_DESCRIPTION:-A Python project}

[![Python Version](https://img.shields.io/badge/python-$PYTHON_VERSION+-blue.svg)](https://www.python.org/downloads/)
[![License](https://img.shields.io/badge/license-$LICENSE_TYPE-green.svg)](LICENSE)
[![Code style: black](https://img.shields.io/badge/code%20style-black-000000.svg)](https://github.com/psf/black)

## Description

${PROJECT_DESCRIPTION:-A comprehensive Python project following modern best practices.}

## Features

- 🚀 Modern Python $PYTHON_VERSION+ support
- 📦 Package management with pip and virtual environments
- 🧪 Testing with pytest
- 🔧 Code formatting with black and isort
- 🕵️ Linting with flake8
- 📝 Type checking with mypy
- 🔒 Pre-commit hooks for code quality
- 📚 Comprehensive documentation
- 🏗️ CI/CD ready structure

## Installation

### Prerequisites

- Python $PYTHON_VERSION or higher
- Git

### Development Setup

1. Clone the repository:
   \`\`\`bash
   git clone https://github.com/$AUTHOR_NAME/$PROJECT_NAME.git
   cd $PROJECT_NAME
   \`\`\`

2. Create and activate a virtual environment:
   \`\`\`bash
   python -m venv venv
   source venv/bin/activate  # On Windows: venv\\Scripts\\activate
   \`\`\`

3. Install the package in development mode:
   \`\`\`bash
   pip install -e .
   \`\`\`

4. Install development dependencies:
   \`\`\`bash
   pip install -r requirements-dev.txt
   \`\`\`

5. Install pre-commit hooks:
   \`\`\`bash
   pre-commit install
   \`\`\`

## Usage

### Command Line Interface

\`\`\`bash
# Run the application
$PROJECT_NAME --help

# Example usage
$PROJECT_NAME input_file.txt

# Verbose output
$PROJECT_NAME --verbose input_file.txt
\`\`\`

### Python API

\`\`\`python
from $PROJECT_NAME import main

# Your code here
\`\`\`

## Development

### Running Tests

\`\`\`bash
# Run all tests
pytest

# Run with coverage
pytest --cov=src

# Run specific test file
pytest tests/test_main.py
\`\`\`

### Code Quality

This project uses several tools to maintain code quality:

\`\`\`bash
# Format code
black src/ tests/

# Sort imports
isort src/ tests/

# Lint code
flake8 src/ tests/

# Type checking
mypy src/

# Run all quality checks
pre-commit run --all-files
\`\`\`

### Project Structure

\`\`\`
$PROJECT_NAME/
├── src/
│   └── $PROJECT_NAME/
│       ├── __init__.py
│       └── main.py
├── tests/
│   ├── __init__.py
│   ├── conftest.py
│   └── test_main.py
├── docs/
│   └── (documentation files)
├── config/
│   └── (configuration files)
├── scripts/
│   └── (utility scripts)
├── pyproject.toml
├── requirements.txt
├── requirements-dev.txt
├── README.md
├── LICENSE
├── .gitignore
├── .editorconfig
└── .pre-commit-config.yaml
\`\`\`

## Contributing

1. Fork the repository
2. Create a feature branch (\`git checkout -b feature/amazing-feature\`)
3. Make your changes
4. Run the test suite (\`pytest\`)
5. Run code quality checks (\`pre-commit run --all-files\`)
6. Commit your changes (\`git commit -m 'Add amazing feature'\`)
7. Push to the branch (\`git push origin feature/amazing-feature\`)
8. Open a Pull Request

### Development Guidelines

- Follow PEP 8 style guide
- Write tests for new functionality
- Update documentation as needed
- Use type hints where appropriate
- Keep commits atomic and well-described

## License

This project is licensed under the $LICENSE_TYPE License - see the [LICENSE](LICENSE) file for details.

## Authors

- **$AUTHOR_NAME** - *Initial work* - [$AUTHOR_NAME](https://github.com/$AUTHOR_NAME)

## Acknowledgments

- Built with modern Python best practices
- Inspired by the Python community's excellent tooling

## Changelog

### [0.1.0] - $(date +%Y-%m-%d)

#### Added
- Initial project structure
- Basic CLI interface
- Comprehensive testing setup
- Development environment configuration

---

For more information, please refer to the [documentation](docs/) or open an issue.
EOF

    # Create LICENSE file based on license type
    case "$LICENSE_TYPE" in
        "MIT")
            cat > LICENSE << EOF
MIT License

Copyright (c) $(date +%Y) $AUTHOR_NAME

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
EOF
            ;;
        "Apache-2.0")
            cat > LICENSE << EOF
Apache License
Version 2.0, January 2004
http://www.apache.org/licenses/

Copyright $(date +%Y) $AUTHOR_NAME

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
EOF
            ;;
        *)
            touch LICENSE
            echo "# License: $LICENSE_TYPE" > LICENSE
            echo "# Please add the full license text here" >> LICENSE
            ;;
    esac
    
    # Create documentation structure
    mkdir -p docs/{api,tutorials,guides}
    
    cat > docs/index.md << EOF
# $PROJECT_NAME Documentation

Welcome to the $PROJECT_NAME documentation!

## Contents

- [API Reference](api/index.md)
- [Tutorials](tutorials/index.md)
- [Developer Guides](guides/index.md)

## Quick Start

${PROJECT_DESCRIPTION:-This is a Python project following modern best practices.}

## Installation

See the [README](../README.md) for installation instructions.
EOF

    cat > docs/api/index.md << EOF
# API Reference

## Modules

### $PROJECT_NAME.main

Main application module containing the CLI interface.

\`\`\`python
from $PROJECT_NAME.main import main
\`\`\`
EOF

    cat > docs/tutorials/index.md << EOF
# Tutorials

## Getting Started

1. [Installation](../README.md#installation)
2. [Basic Usage](../README.md#usage)
3. [Development Setup](../README.md#development-setup)

## Advanced Topics

Coming soon...
EOF

    cat > docs/guides/index.md << EOF
# Developer Guides

## Contributing

See the [Contributing](../README.md#contributing) section in the README.

## Code Style

This project follows:
- PEP 8 for Python code style
- Black for code formatting
- isort for import sorting
- Type hints for better code documentation
EOF
}

# Initialize git repository
initialize_git_repository() {
    if ! command -v git &> /dev/null; then
        print_warning "Git not available, skipping repository initialization"
        return 0
    fi
    
    print_info "Initializing git repository..."
    
    git init
    git add .
    git commit -m "Initial commit: Project structure for $PROJECT_NAME

- Add modern Python project structure
- Configure development tools (black, isort, flake8, mypy)
- Set up testing with pytest
- Add comprehensive documentation
- Configure pre-commit hooks
- Add proper .gitignore and .gitattributes"
    
    print_success "Git repository initialized with initial commit"
}

# Set up pre-commit hooks
setup_precommit_hooks() {
    print_info "Setting up pre-commit hooks..."

    # Install pre-commit hooks if pre-commit is available
    if [[ -d "venv" ]] && command -v pre-commit &> /dev/null; then
        source venv/bin/activate
        pre-commit install
        print_success "Pre-commit hooks installed"
    else
        print_warning "pre-commit or virtual environment not available."
        print_info "Install pre-commit later with: pip install pre-commit && pre-commit install"
    fi
}

# Execute main function if script is run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi