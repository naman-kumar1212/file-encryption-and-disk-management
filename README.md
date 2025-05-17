# File Encryption and Disk Management

A **secure command-line utility** that allows users to encrypt sensitive files and manage disk storage efficiently. The project is designed to offer a lightweight, easily extensible, and script-based solution for users and system administrators who want essential security and storage tools without the overhead of large GUI applications.

---

## 🔍 About the Project

In the modern digital era, **data privacy** and **storage optimization** are increasingly critical. Many users deal with private files they wish to secure, but lack simple tools to encrypt them. At the same time, disk space can be wasted due to redundant or oversized files, yet users often lack clear insight into what's occupying their storage.

This project solves both problems:

* It provides **AES encryption and decryption** of files using `openssl`, making it easy to securely store or share sensitive data.
* It also includes **disk usage monitoring** with utilities like `df` and `du`, allowing users to:

  * View free and used disk space
  * Analyze directory sizes
  * Identify large files
  * Get suggestions for cleanup

These functionalities are packaged in a user-friendly **Bash shell script**, ideal for scripting automation, system maintenance, or basic security tasks.

---

## 🔐 Features

* **Encrypt Files**: Secure files with password-based AES-256 encryption using `openssl`.
* **Decrypt Files**: Safely restore original files after validation.
* **Disk Usage Report**: View disk utilization and warnings when space runs low.
* **Directory Analyzer**: Scan directories to identify large or unnecessary files.
* **Command-Line Interface**: Lightweight and fast, without any graphical overhead.

---

## 📂 Project Structure

```
file-encryption-and-disk-management/
│
├── SecureVault.sh        # Main script
├── README.md             # Documentation
└── LICENSE               # License (MIT)
```

---

## 🛠️ Technologies Used

* **Bash Shell Scripting**
* **OpenSSL** for AES encryption
* **df, du** for disk management
* **Standard UNIX tools** (e.g., `read`, `echo`, `find`)

---

## 🚀 Getting Started

### Prerequisites

* Unix-based OS (Linux/macOS)
* Bash shell
* Utilities: `openssl`, `df`, `du`, `find`

### Installation

```bash
git clone https://github.com/naman-kumar1212/file-encryption-and-disk-management.git
cd file-encryption-and-disk-management
chmod +x SecureVault.sh
```

### Usage

```bash
./SecureVault.sh
```

Follow on-screen options:

1. Encrypt/Decrypt files
2. Check disk space
3. Analyze disk usage
4. Exit

---

## 🧠 Future Improvements

* Add logging and audit trails
* Support for folder encryption
* Add command-line arguments for automation
* Cross-platform support (Windows via WSL)
* Cloud backup integration

---

## 📄 License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for more info.
