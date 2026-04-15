# ip-scan

A lightweight Bash utility for scanning IP CIDR ranges, identifying hosts with port **443 (HTTPS)** open, and recording those that respond with **HTTP 403**.

This tool is designed for infrastructure audits, CDN/IP range analysis, and security research where quick HTTPS reachability and response-code filtering is required.

---

## Features

- 🚀 High‑performance scanning using **masscan**
- 🔐 HTTPS validation using **curl**
- 📄 CSV output for easy post‑processing
- 🧾 Comment‑aware CIDR input file
- ⚙️ Simple, dependency‑light Bash script

---

## Requirements

- Linux system
- `masscan`
- `curl`
- Root or sudo access (required by masscan)

### Install dependencies

```bash
# Debian / Ubuntu
sudo apt update && sudo apt install -y masscan curl

# RHEL / CentOS
sudo yum install -y masscan curl
```

---

## Usage

### 1. Prepare CIDR list

Create a text file (for example `cidrs.txt`) with one CIDR per line:

```text
# Example CIDRs
192.168.1.0/24
10.0.0.0/16
172.16.5.10/32
```

- Lines starting with `#` are ignored
- IPv4 CIDRs only

### 2. Run the scanner

```bash
sudo bash check_ips.sh cidrs.txt
```

---

## Output

- **Terminal:** live output of IPs returning HTTP 403
- **result.csv:** CSV file with a single column:

```csv
ip
1.2.3.4
5.6.7.8
```

The file is created (or overwritten) in the current working directory.

---

## How It Works

1. **masscan** scans all provided CIDRs for port `443` with a controlled rate
2. IPs with an open HTTPS port are extracted
3. Each IP is queried via HTTPS using `curl`
   - TLS errors are ignored
   - Timeouts are enforced
4. Hosts returning **HTTP 403** are saved to `result.csv`

---

## Configuration

You can tune the following parameters directly inside `check_ips.sh`:

| Setting | Default | Description |
|------|---------|------------|
| `--rate` | `1000` | masscan packets per second |
| `--connect-timeout` | `3` | curl connection timeout (seconds) |
| `--max-time` | `5` | curl max request time (seconds) |
| `-p` | `443` | port to scan |

---

## Use Cases

- CDN / WAF IP range validation
- Cloud provider IP inspection
- Security research and filtering
- HTTPS endpoint discovery

---

## Safety & Ethics

⚠️ **Only scan networks you own or are authorized to test.**

Unauthorized scanning may violate laws, provider policies, or acceptable‑use rules.

---

## License

Licensed under the **GNU General Public License v3.0**.

See [LICENSE](LICENSE) for details.

---

## Contributing

Pull requests are welcome.

If you plan a significant change, please open an issue first to discuss it.

---

## Author

**Mohammad Hassan Roohbakhsh**  
GitHub: https://github.com/roohbakhsh

