# UTS iHPC Computing Node Jumper

**A smart bash script for UTS iHPC users to automatically select and connect to the optimal Venus compute node based on resource availability.**

---

## ⚠️ Important Notice

### Target Users
This tool is designed specifically for **UTS (University of Technology Sydney) Research Staff and HDR (Higher Degree Research) Students** who have access to the iHPC (Institute for High Performance Computing) cluster.

### Disclaimer
- This is an **unofficial tool** created to improve workflow efficiency on UTS iHPC
- Users **MUST comply with all [UTS iHPC usage policies and guidelines](https://www.uts.edu.au/research-and-teaching/our-research/research-facilities/high-performance-computing)**
- By using this tool, you agree to:
  - Follow all iHPC resource allocation policies
  - Respect fair-share computing principles
  - Not abuse or monopolize computing resources
  - Report any issues or concerns to iHPC support
- The author(s) are **not responsible** for any policy violations or issues arising from the use of this tool
- This tool does not bypass any security measures or access controls
- **Always prioritize manual node selection if you have specific requirements**

### System Compatibility
- ✅ Designed for: **UTS iHPC Janus/Venus cluster**
- ✅ Jump server: **janus0.ihpc.uts.edu.au**
- ✅ Target nodes: **Venus compute nodes (venus1-venus32)**
- ⚠️ Requires: Access to the `cnode` command on janus0

---

## 🚀 Quick Start (for UTS iHPC users)

1. SSH to janus0: `ssh your_username@janus0.ihpc.uts.edu.au`
2. Add the script to your `~/.bashrc` (see [Installation](#installation))
3. Reload bashrc: `source ~/.bashrc`
4. Run: `jump_venus` or `vjump`
5. Enjoy! 🎉

---

## Features

- 🚀 **Automatic Node Selection**: Intelligently picks the best available Venus node
- 📊 **Resource-Aware**: Prioritizes nodes with lower GPU/CPU usage
- 👥 **User-Aware**: Prefers nodes without active users when available
- 🔒 **Safe**: Only connects to nodes with "Connect=yes" status
- 💬 **Clean Output**: Minimal, informative messages
- ⚡ **Fast**: Quick execution with efficient parsing

## How It Works

The script follows a priority-based selection algorithm:

### Selection Criteria (in order):

1. **Must-have**: Node name starts with "venus"
2. **Must-have**: Node "Connect" status is "yes"
3. **Priority 1**: No active users (if User column exists)
4. **Priority 2**: Lowest GPU usage (%)
5. **Priority 3**: Lowest CPU usage (%)

### Workflow:

```
cnode → Filter venus nodes → Filter Connect=yes → Sort by priority → SSH to best node
```

## Installation

### 1. Add to your `.bashrc`

Copy the following code to your `~/.bashrc` file:

```bash
## Jump to Computing Node
# Script to automatically select and jump to the best venus compute node
# You can make jump_venus run automatically when bashrc is loaded, but with this, every new terminal will try to login to a venus node automatically. It is generally recommended to call it manually.
# If you do want to run it automatically at startup, add a line like jump_venus (or vjump) at the end of your .bashrc.

jump_venus() {
    # Only allow the function on node janus0
    if [ "$(hostname)" != "janus0.ihpc.uts.edu.au" ]; then
        echo "Cannot jump: jump_venus can only run on jump server janus0 (current host: $(hostname))"
        return 1
    fi

    local cnode_out venus_lines best_node=""
    
    # Step 1: Get node status
    cnode_out="$(cnode)"
    if [ -z "$cnode_out" ]; then
        echo "Cannot jump: failed to get node status (cnode command failed)"
        return 1
    fi
    
    # Step 2 & 3.0: Filter for lines starting with "venus" and "Connect" column is "yes" (ignore header)
    # Connect is in column 3, match case-insensitively using tolower()
    venus_lines=$(echo "$cnode_out" | awk '
        NR==1 { next }  # Skip header
        $1 ~ /^venus/ && tolower($3) ~ /yes/ { print $0 }
    ')
    
    if [ -z "$venus_lines" ]; then
        echo "Cannot jump: no available venus node (all venus nodes Connect state is not yes)"
        return 1
    fi
    
    # Step 3.1-3.3: Pick the optimal node according to priority
    # Priority:
    #   1. User(s) empty (no_user=1 is preferred) - if User column exists
    #   2. Lowest %GPU
    #   3. Lowest %CPU
    best_node=$(echo "$venus_lines" | awk '
        BEGIN { OFS="\t" }
        {
            node = $1
            
            # Determine format based on field count
            # If 7 columns: Node Status Connect Load1 Load2 %GPU %CPU
            # If 8+: may include User(s) column
            if (NF == 7) {
                # 7-column format: no User column
                gpu_str = $6  # %GPU
                cpu_str = $7  # %CPU
                user = ""
                no_user = 1
            } else if (NF >= 8) {
                # 8+ column format: possibly User column
                # Assume User is third-to-last, %GPU second-to-last, %CPU last
                user = $(NF-2)
                gpu_str = $(NF-1)
                cpu_str = $NF
                if (user == "" || user == "-" || user ~ /^[0-9.]+%$/) {
                    # If user is empty or contains %, it's not a user column
                    no_user = 1
                    # Re-parse
                    gpu_str = $(NF-1)
                    cpu_str = $NF
                } else {
                    no_user = 0
                }
            } else {
                # Other cases
                gpu_str = $(NF-1)
                cpu_str = $NF
                user = ""
                no_user = 1
            }
            
            # Extract numbers (strip %)
            gsub("%", "", gpu_str)
            gsub("%", "", cpu_str)
            gpu = gpu_str + 0
            cpu = cpu_str + 0
            
            # Output: node, no_user flag, GPU%, CPU%, user list
            print node, no_user, gpu, cpu, user
        }
    ' | sort -t$'\t' -k2,2nr -k3,3n -k4,4n | head -n1)
    
    if [ -z "$best_node" ]; then
        echo "Cannot jump: failed to select best node (node parsing failed)"
        return 1
    fi
    
    # Extract node name and related info
    node_name=$(echo "$best_node" | cut -f1)
    no_user=$(echo "$best_node" | cut -f2)
    gpu_usage=$(echo "$best_node" | cut -f3)
    cpu_usage=$(echo "$best_node" | cut -f4)
    user_list=$(echo "$best_node" | cut -f5)
    
    echo "Selected optimal node: $node_name"
    echo "  - GPU usage: ${gpu_usage}%"
    echo "  - CPU usage: ${cpu_usage}%"
    if [ "$no_user" -eq 1 ]; then
        echo "  - Current user: (none)"
    else
        echo "  - Current user: $user_list"
    fi
    ssh "$node_name"
}
alias vjump="jump_venus"
```

### 2. Reload your bashrc

```bash
source ~/.bashrc
```

## Usage

### Manual invocation (Recommended)

```bash
jump_venus
# or use the alias
vjump
```

### Auto-run on login (Use with caution)

To automatically run when opening a new terminal, add this line at the end of your `.bashrc`:

```bash
jump_venus
```

⚠️ **Warning**: This will attempt to connect to a venus node every time you open a new terminal.

## Example Output

### Success:

```bash
$ jump_venus
Selected optimal node: venus25
  - GPU usage: 0.0%
  - CPU usage: 0.2%
  - Current user: (none)
```

### Failure scenarios:

```bash
# Wrong jump server
Cannot jump: jump_venus can only run on jump server janus0 (current host: venus25)

# cnode command failed
Cannot jump: failed to get node status (cnode command failed)

# No available nodes
Cannot jump: no available venus node (all venus nodes Connect state is not yes)

# Parsing error
Cannot jump: failed to select best node (node parsing failed)
```

## Configuration

### Customize jump server hostname

Edit this line in the function:

```bash
if [ "$(hostname)" != "janus0.ihpc.uts.edu.au" ]; then
```

Replace `janus0.ihpc.uts.edu.au` with your jump server hostname.

### Customize node prefix

To select nodes with a different prefix (e.g., "mars" instead of "venus"), edit:

```bash
$1 ~ /^venus/
```

Replace `venus` with your desired prefix.

### Adjust Connect column position

If your `cnode` output has a different format, adjust the column number:

```bash
tolower($3) ~ /yes/
```

Replace `$3` with the correct column number for the Connect field.

## Requirements

- **Bash**: Version 4.0 or higher
- **awk**: GNU awk (gawk) recommended
- **cnode**: Custom command that outputs node status (must be available in PATH)
- **ssh**: OpenSSH client

## Expected `cnode` Output Format

The script expects `cnode` to output a table with at least these columns:

```
Node      Status  Connect  Load1  Load2  %GPU   %CPU   [User(s)]
venus25   0       yes      0.8    9.4    0.0%   0.2%   [optional]
venus26   0       yes      1.2    15.3   5.0%   10.5%  user1,user2
```

- **Column 1**: Node name
- **Column 3**: Connect status (case-insensitive "yes")
- **Column 6**: GPU usage percentage (7-column format)
- **Column 7**: CPU usage percentage (7-column format)

## Troubleshooting

### Problem: Always shows "no available venus node"

**Solution**: Check if:
1. Venus nodes exist in `cnode` output
2. Connect column is in position 3
3. Connect value is "yes" (case-insensitive)

Debug by running:
```bash
cnode | awk 'NR==1 || $1 ~ /^venus/'
```

### Problem: Wrong node selected

**Solution**: Verify the column positions for %GPU and %CPU:
```bash
cnode | awk '$1 ~ /^venus/ {print "Node:", $1, "Fields:", NF, "GPU:", $6, "CPU:", $7}'
```

### Problem: Function not found after reloading

**Solution**: Make sure you saved the `.bashrc` file and ran:
```bash
source ~/.bashrc
```

## License

MIT License - Feel free to use and modify for your needs.

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## Support & Contact

For iHPC-related issues, please contact:
- **UTS iHPC Support**: [its.support@uts.edu.au](mailto:its.support@uts.edu.au)
- **iHPC Documentation**: [UTS Research Computing](https://www.uts.edu.au/research-and-teaching/our-research/research-facilities/high-performance-computing)

For issues with this script, please open an issue on GitHub.

## Acknowledgments

Thanks to UTS iHPC team for providing excellent computing infrastructure for research and education.

---

## 🎓 About UTS iHPC

The UTS Institute for High Performance Computing (iHPC) provides high-performance computing resources to support cutting-edge research across various disciplines. The facility includes multiple compute nodes with GPU acceleration capabilities, designed to handle computationally intensive tasks.

**Learn more**: [UTS Research Facilities](https://www.uts.edu.au/research-and-teaching/our-research/research-facilities)

---

**Note**: This is an unofficial community tool specifically designed for the UTS iHPC environment. It requires the `cnode` command available on janus0. If you're from another institution, you may need to adapt it for your specific cluster setup.

