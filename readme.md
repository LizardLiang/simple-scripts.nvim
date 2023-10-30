# Simple-Scripts

This script is bunch of scripts that help me with my daily job
Hope this script will help you too

## Installation

### Lazy

```bash
use "LizardLiang/simple-scripts.nvim"
```

## Features

### 🚀 Turbo console

This tool is inspire by the turbo console extension for vscode,
the tool will generate normal logging function like console.log in javascript, print in python and std::cout in c++.

`require('simple-scripts').insert_debug_message()`

### 🏭 Header generator

This tool is used for generate header declaration for c++ functions

`require('simple-scripts').generate_cpp_header()`

### 🔄 Header source toggle

This tool is used for toggle between header and source file in c++ project

`require('simple-scripts').toggle()`
