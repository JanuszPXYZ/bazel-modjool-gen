# bazel-modjool-gen

Bazel Modjool Gen is a Swift CLI tool that I created for myself to quickly generate modules in iOS workspace that is created through [Bazel](https://github.com/bazelbuild/bazel). 
The tool generates directories for a given module and adds them to the root `BUILD.bazel` file, which speeds up the development process whenever your iOS app is modularized and you want
to extend it by additional modules (or, in other words, if you want to add new functionality to your app, but it has to be contained in a separate module). 
The generated directories contain template files that you are free to modify. `bazel-modjool-gen` is a very simple tool, you run it in your Bazel directory that contains 
your root `BUILD` file (or `WORKSPACE`) with the name of the feature and it gets added to your Bazel deps. You can check how it works in the short video.

## Installation

#### 1) Clone the repository:
`git clone https://github.com/JanuszPXYZ/bazel-modjool-gen`

#### 2) Build for release:
`swift build -c release`

#### 3) Move the executable to `usr/local/bin`
`cp .build/release/bazel-modjool-gen /usr/local/bin`
(You may need to run it using `sudo`)

#### 4) Run the tool in your terminal :)
`bazel-modjool-gen`

## Usage
`bazel-modjool-gen` has the following flags that you can run it with:

#### 1) `-g, --generatePair`
This flag tells the tool to generate a pair of modules: a private one and a public one, which is usually the pattern in large-scale modular iOS architectures. The private module contains
the actual implementations, while the public module provides the protocols that "expose" the module's functionality to the outside world. The visibility for the private module is set to
`__pkg__` in the module's `BUILD` file, while the public module's visibility is set to `//visibility:public`.

#### 2) `-t, --template`
Template type to use (values: `feature`, `service`, `utility`, `viewmodel`; **default `feature`**). Ideally, I'd like the templating to be more robust in future releases. It's very one-dimensional and
makes a lot of strong assumptions.

#### 3) `-d, --dry-run`
Show what would be generated without creating files

#### 4) `-v, --verbose`
Enable verbose output

#### 5) `--workspace <workspace>`
Path to Bazel workspace root (by default it's set to `.`, as it assumes that the tool is going to be used in an existing Bazel workspace)

## Example
```bash
  bazel-modjool-gen UserProfile # generates a single private module named UserProfile
  bazel-modjool-gen PaymentService --template=service # generates a single private module named PaymentService that implements the service template
  bazel-modjool-gen SettingsFeature --dry-run # performs a dry-run with a module named SettingsFeature
```
## Video Presentation

https://github.com/user-attachments/assets/cf1d7e41-28b5-4959-ad75-2e284b6e54f3


