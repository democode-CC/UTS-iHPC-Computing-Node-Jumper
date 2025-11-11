## Jump to Computing Node
# Script to automatically select and jump to the best venus compute node
# You can make jump_venus run automatically when bashrc is loaded, but with this, every new terminal will try to login to a venus node automatically. It is generally recommended to call it manually.
# If you do want to run it automatically at startup, add a line like jump_venus (or vjump) at the end of your .bashrc.
# For example:

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

# If you want this to run when bashrc is loaded, add the following code:
# (Warning: This will cause each new shell to automatically login to a venus node, use with caution!)
# jump_venus

# The most common usage is to enter jump_venus or vjump manually.

jump_venus
