# ConfigCommon

A centralized repository for maintaining and distributing common configuration files across multiple development projects. Provides automated synchronization through GitHub Actions workflows and PowerShell scripts.

## 🚀 Features

- **Multi-Engine Support**: Configuration templates for Unreal Engine and Daemon Engine
- **Automated Sync**: GitHub Actions workflow for automatic file synchronization
- **Flexible Configuration**: Easily switch between different engine templates
- **Batch Deployment**: PowerShell script for deploying workflows to multiple repositories
- **Version Control**: Git LFS support and proper attribute configurations

## 📦 Available Configuration Templates

### Unreal Engine Templates
- **UnrealEngine.gitignore**: Comprehensive ignore rules for Unreal Engine projects
  - Binary exclusions (Binaries/, Intermediate/, DerivedDataCache/)
  - Build artifacts and IDE files
  - Asset-specific exclusions
- **UnrealEngine.gitattributes**: Git LFS configurations for Unreal Engine assets
  - Binary file handling
  - Large asset management

### Daemon Engine Templates
- **DaemonEngine.gitignore**: Specialized ignore rules for Daemon Engine (C++ game engine with V8 JavaScript)
  - DirectX SDK exclusions
  - Build artifacts and intermediate files
  - Visual Studio 2022 specific files
- **DaemonEngine.gitattributes**: Git configurations for Daemon Engine projects
  - V8 JavaScript engine integration
  - Build tool configurations

## 🔧 Quick Start

### Method 1: Manual Setup

1. **Copy the workflow file** to your repository:
   ```bash
   mkdir -p .github/workflows
   curl -o .github/workflows/sync-config-common.yml \
     https://raw.githubusercontent.com/dadavidtseng/ConfigCommon/main/sync-config-common.yml
   ```

2. **Customize the workflow** (optional):
   - Edit `.github/workflows/sync-config-common.yml`
   - Change default source files to match your engine

3. **Trigger the workflow**:
   - Go to Actions tab in your repository
   - Select "Sync Config Files from dadavidtseng/ConfigCommon"
   - Click "Run workflow"

### Method 2: Using PowerShell Script

```powershell
# Deploy to single repository
.\CopyYML.ps1 -TargetRepositories @("username/my-project")

# Deploy to multiple repositories
.\CopyYML.ps1 -TargetRepositories @("username/project1", "username/project2")
```

## 📝 Usage Examples

### Example 1: Unreal Engine Project (Default)

The workflow defaults to Unreal Engine templates. Simply run the workflow with default settings:

**GitHub Actions UI:**
- sync .gitignore: ✅ (default: `UnrealEngine.gitignore`)
- sync .gitattributes: ✅ (default: `UnrealEngine.gitattributes`)
- sync .editorconfig: ✅
- sync .clang-format: ❌

**Result:**
- `.gitignore` ← synced from `UnrealEngine.gitignore`
- `.gitattributes` ← synced from `UnrealEngine.gitattributes`

### Example 2: Daemon Engine Project

To use Daemon Engine templates, modify the workflow file:

**Edit `.github/workflows/sync-config-common.yml`:**

```yaml
gitignore_source:
  description: '.gitignore source file name (e.g., UnrealEngine.gitignore, DaemonEngine.gitignore)'
  required: false
  default: 'DaemonEngine.gitignore'  # ← Changed to DaemonEngine
  type: string

gitattributes_source:
  description: '.gitattributes source file name (e.g., UnrealEngine.gitattributes, DaemonEngine.gitattributes)'
  required: false
  default: 'DaemonEngine.gitattributes'  # ← Changed to DaemonEngine
  type: string
```

**Or use workflow dispatch inputs:**
- gitignore source file name: `DaemonEngine.gitignore`
- gitattributes source file name: `DaemonEngine.gitattributes`

### Example 3: Custom Configuration

Sync additional files using the `additional_files` input:

**Format:** `local_file:remote_file,local_file2:remote_file2`

**Example:**
```
.clang-tidy:.clang-tidy,LICENSE:MIT-license.txt
```

## 🔄 Workflow Configuration

### Sync Options

| Option | Description | Default | Available Sources |
|--------|-------------|---------|-------------------|
| `sync_gitignore` | Enable .gitignore sync | `true` | - |
| `gitignore_source` | Source file for .gitignore | `UnrealEngine.gitignore` | `UnrealEngine.gitignore`, `DaemonEngine.gitignore` |
| `sync_gitattributes` | Enable .gitattributes sync | `true` | - |
| `gitattributes_source` | Source file for .gitattributes | `UnrealEngine.gitattributes` | `UnrealEngine.gitattributes`, `DaemonEngine.gitattributes` |
| `sync_editorconfig` | Enable .editorconfig sync | `true` | - |
| `editorconfig_source` | Source file for .editorconfig | `.editorconfig` | `.editorconfig` |
| `sync_clangformat` | Enable .clang-format sync | `false` | - |
| `clangformat_source` | Source file for .clang-format | `.clang-format` | `.clang-format` |
| `additional_files` | Additional custom files | `''` | Format: `local:remote,local2:remote2` |

### Scheduled Execution

The workflow runs automatically:
- **Schedule**: Every Monday at 2:00 AM UTC
- **Manual**: Trigger anytime via Actions tab

## 🛠️ Development

### Adding New Engine Templates

1. **Create configuration files**:
   ```bash
   # Follow PascalCase naming convention
   touch NewEngine.gitignore
   touch NewEngine.gitattributes
   ```

2. **Add to git**:
   ```bash
   git add NewEngine.gitignore NewEngine.gitattributes
   git commit -m "feat: add NewEngine configuration templates"
   ```

3. **Update documentation**:
   - Add to CLAUDE.md architecture diagram
   - Add usage examples to README.md

### File Naming Convention

All configuration templates follow **PascalCase** naming:
- ✅ `UnrealEngine.gitignore`
- ✅ `DaemonEngine.gitattributes`
- ❌ `unreal-engine.gitignore` (deprecated)

## 📄 License

Apache License 2.0 - See [LICENSE](LICENSE) for details.

## 🤝 Contributing

Contributions are welcome! Please feel free to submit issues or pull requests.

## 🔗 Related Resources

- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [Git LFS Documentation](https://git-lfs.github.io/)
- [Unreal Engine Version Control Guidelines](https://docs.unrealengine.com/5.0/en-US/using-version-control-with-unreal-engine/)
