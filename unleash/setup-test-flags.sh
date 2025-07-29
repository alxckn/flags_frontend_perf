#!/bin/bash

# Setup test feature flags in Unleash
# Run this on a BLANK Unleash instance only

UNLEASH_URL="http://localhost:4242"

# Wait for Unleash to be ready
echo "Waiting for Unleash to be ready..."
while ! curl -s "$UNLEASH_URL/health" > /dev/null; do
    sleep 2
done
echo "Unleash is ready!"

# Login and get session cookie
echo "Logging in as admin..."
COOKIE_JAR=$(mktemp)
LOGIN_RESPONSE=$(curl -s -c "$COOKIE_JAR" -X POST "$UNLEASH_URL/auth/simple/login" \
    -H "Content-Type: application/json" \
    -d '{"username":"admin","password":"unleash4all"}')

if [[ $LOGIN_RESPONSE == *"error"* ]]; then
    echo "Login failed"
    exit 1
fi

echo "Login successful!"

# Function to create a segment and store its ID
create_segment() {
    local name=$1
    local description=$2
    local constraints=$3

    echo "Creating segment: $name"

    RESPONSE=$(curl -s -b "$COOKIE_JAR" -X POST "$UNLEASH_URL/api/admin/segments" \
        -H "Content-Type: application/json" \
        -d "{
            \"name\": \"$name\",
            \"description\": \"$description\",
            \"project\": \"default\",
            \"constraints\": $constraints
        }")

    # Extract and store segment ID
    SEGMENT_ID=$(echo "$RESPONSE" | grep -o '"id":[0-9]*' | head -1 | cut -d':' -f2)
    eval "${name//-/_}_SEGMENT_ID=$SEGMENT_ID"
    echo "✓ Created segment: $name (ID: $SEGMENT_ID)"
}

# Function to create a feature flag
create_feature_flag() {
    local name=$1
    local description=$2

    echo "Creating feature flag: $name"

    curl -s -b "$COOKIE_JAR" -X POST "$UNLEASH_URL/api/admin/projects/default/features" \
        -H "Content-Type: application/json" \
        -d "{
            \"name\": \"$name\",
            \"description\": \"$description\",
            \"type\": \"release\"
        }" > /dev/null

    echo "✓ Created: $name"
}

# Function to add activation strategy to a feature flag
add_activation_strategy() {
    local feature_name=$1
    local strategy_name=$2
    local strategy_params=$3
    local segments=$4

    echo "Adding $strategy_name strategy to $feature_name"

    local strategy_data="{
        \"name\": \"$strategy_name\",
        \"parameters\": $strategy_params"
    
    if [ -n "$segments" ]; then
        strategy_data+=",\"segments\": $segments"
    fi
    
    strategy_data+="}"

    curl -s -b "$COOKIE_JAR" -X POST "$UNLEASH_URL/api/admin/projects/default/features/$feature_name/environments/development/strategies" \
        -H "Content-Type: application/json" \
        -d "$strategy_data" > /dev/null

    echo "✓ Added $strategy_name strategy to $feature_name"
}

# Function to enable a feature flag in development environment
enable_feature_flag() {
    local name=$1

    echo "Enabling feature flag: $name in development"

    curl -s -b "$COOKIE_JAR" -X POST "$UNLEASH_URL/api/admin/projects/default/features/$name/environments/development/on" \
        -H "Content-Type: application/json" > /dev/null

    echo "✓ Enabled: $name"
}

echo ""
echo "Creating segments..."

# Create segments for different user types
create_segment "eu-users" "European users (FR, DE, IT)" '[{
    "contextName": "tld",
    "operator": "IN",
    "values": ["fr", "de", "it"]
}]'

create_segment "pro-users" "Professional account users" '[{
    "contextName": "accountType",
    "operator": "IN",
    "values": ["pro"]
}]'

create_segment "patient-users" "Patient account users" '[{
    "contextName": "accountType",
    "operator": "IN",
    "values": ["patient"]
}]'

create_segment "mobile-users" "Mobile platform users" '[{
    "contextName": "platform",
    "operator": "IN",
    "values": ["mobile"]
}]'

create_segment "desktop-users" "Desktop platform users" '[{
    "contextName": "platform",
    "operator": "IN",
    "values": ["desktop", "web"]
}]'

echo ""
echo "Creating 1000 test feature flags..."

# Arrays for random selection
SEGMENTS=($eu_users_SEGMENT_ID $pro_users_SEGMENT_ID $patient_users_SEGMENT_ID $mobile_users_SEGMENT_ID $desktop_users_SEGMENT_ID)
ROLLOUT_PERCENTAGES=(10 25 50 75 90)
SEGMENT_NAMES=("eu-users" "pro-users" "patient-users" "mobile-users" "desktop-users")

# Function to get random array element
get_random_element() {
    local arr=("$@")
    echo "${arr[$((RANDOM % ${#arr[@]}))]}"
}

# Function to get multiple random segments (1-3 segments)
get_random_segments() {
    local num_segments=$((RANDOM % 3 + 1))  # 1-3 segments
    local selected_segments=()
    local used_indices=()
    
    for ((i=0; i<num_segments; i++)); do
        local idx
        while true; do
            idx=$((RANDOM % ${#SEGMENTS[@]}))
            if [[ ! " ${used_indices[@]} " =~ " ${idx} " ]]; then
                used_indices+=($idx)
                selected_segments+=(${SEGMENTS[$idx]})
                break
            fi
        done
    done
    
    # Convert to JSON array format
    local segments_json="["
    for ((i=0; i<${#selected_segments[@]}; i++)); do
        segments_json+="${selected_segments[$i]}"
        if [[ $i -lt $((${#selected_segments[@]} - 1)) ]]; then
            segments_json+=", "
        fi
    done
    segments_json+="]"
    echo "$segments_json"
}

# Create 1000 feature flags with distribution:
# 30% (300) fully activated
# 40% (400) with segmentation and rollout
# 30% (300) disabled

echo "Creating feature flags (this may take a few minutes)..."

for i in $(seq 1 1000); do
    if [[ $((i % 100)) -eq 0 ]]; then
        echo "Progress: $i/1000 flags created..."
    fi
    
    flag_name="test-flag-$(printf "%04d" $i)"
    
    if [[ $i -le 300 ]]; then
        # 30% fully activated (1-300)
        create_feature_flag "$flag_name" "Fully activated test flag $i"
        enable_feature_flag "$flag_name"
        add_activation_strategy "$flag_name" "default" '{}' ""
        
    elif [[ $i -le 700 ]]; then
        # 40% with segmentation and rollout (301-700)
        rollout=$(get_random_element "${ROLLOUT_PERCENTAGES[@]}")
        segments=$(get_random_segments)
        
        create_feature_flag "$flag_name" "Segmented test flag $i with $rollout% rollout"
        enable_feature_flag "$flag_name"
        add_activation_strategy "$flag_name" "flexibleRollout" "{\"rollout\": \"$rollout\", \"stickiness\": \"sessionId\", \"groupId\": \"$flag_name\"}" "$segments"
        
    else
        # 30% disabled (701-1000)
        create_feature_flag "$flag_name" "Disabled test flag $i"
        # Don't enable these flags - they remain disabled
    fi
done

echo ""
echo "Feature flags setup complete!"
echo "Visit $UNLEASH_URL to view your feature flags"
echo "Username: admin"
echo "Password: unleash4all"
echo ""
echo "Configuration summary:"
echo "Created 1000 feature flags with the following distribution:"
echo "- Flags 0001-0300 (300 flags): Fully activated with default strategy"
echo "- Flags 0301-0700 (400 flags): Segmented with random rollout percentages (10%, 25%, 50%, 75%, 90%)"
echo "- Flags 0701-1000 (300 flags): Disabled (no strategies)"
echo ""
echo "Segments created:"
echo "- eu-users: TLD in [fr, de, it]"
echo "- pro-users: AccountType = pro"
echo "- patient-users: AccountType = patient" 
echo "- mobile-users: Platform = mobile"
echo "- desktop-users: Platform in [desktop, web]"

# Cleanup
rm -f "$COOKIE_JAR"