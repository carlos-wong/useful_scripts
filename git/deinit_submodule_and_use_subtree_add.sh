#!/bin/bash

# Summary: This script converts a Git submodule to a subtree and includes debugging statements.

echo "Starting the submodule to subtree conversion script."

# Check if submodule path is provided as an argument
if [ -z "$1" ]; then
    echo "Usage: $0 <submodule-path>"
    exit 1
fi

# Assign the submodule path to a variable
SUBMODULE_PATH=$1
echo "The command: SUBMODULE_PATH is set to '$SUBMODULE_PATH'"

echo "Submodule path provided. Proceeding with conversion."

# Check if the current repository is clean
if ! git diff-index --quiet HEAD --; then
    echo "The command: git diff-index --quiet HEAD --"
    echo "The current repository is not clean. Please commit or stash your changes before proceeding."
    exit 1
fi

# Navigate to the submodule directory
echo "The command: cd $SUBMODULE_PATH"
cd $SUBMODULE_PATH || { echo "Failed to navigate to the submodule directory. Exiting."; exit 1; }

# Record the submodule's remote URL
SUBMODULE_URL=$(git config --get remote.origin.url)
echo "The command: git config --get remote.origin.url"
echo "Submodule remote URL: $SUBMODULE_URL"

# Get the SHA-1 of the HEAD
HEAD_SHA1=$(git rev-parse HEAD)
echo "The command: git rev-parse HEAD"
echo "SHA-1 of HEAD: $HEAD_SHA1"

# List all remote branches without removing the 'origin/' prefix
ALL_BRANCHES=$(git branch -r)
echo "The command: git branch -r"
echo "All remote branches:"
echo "$ALL_BRANCHES"

# Initialize an array to hold branches that point to the same SHA-1 as HEAD
MATCHING_BRANCHES=()

# Iterate over all branches to find ones that match the HEAD SHA-1
for branch in $ALL_BRANCHES; do
    # Remove any leading whitespace
    branch=$(echo $branch | sed 's/^[[:space:]]*//')
    # Get the SHA-1 of the branch point
    BRANCH_SHA1=$(git rev-parse $branch)
    echo "The command: git rev-parse $branch"
    # Check if the branch name starts with 'origin/' and compare with the SHA-1 of HEAD
    if [[ "$branch" == origin/* ]] && [ "$BRANCH_SHA1" = "$HEAD_SHA1" ]; then
        # Remove 'origin/' from the branch name before adding to MATCHING_BRANCHES
        clean_branch=${branch#origin/}
        MATCHING_BRANCHES+=("$clean_branch")
        echo "Branch '$clean_branch' matches HEAD SHA-1 and is added to MATCHING_BRANCHES"
    fi
done

# Debug the MATCHING_BRANCHES
echo "Matching branches:"
printf '%s\n' "${MATCHING_BRANCHES[@]}"

# Check if there is at least one matching branch
if [ ${#MATCHING_BRANCHES[@]} -eq 0 ]; then
    echo "No matching branch found for SHA-1 $HEAD_SHA1"
    exit 1
else
    # Get the first one that matches
    SUBMODULE_BRANCH=${MATCHING_BRANCHES[0]}
    echo "Submodule HEAD branch: $SUBMODULE_BRANCH"
fi

# Navigate back to the main repository root
echo "The command: cd -"
cd - || { echo "Failed to navigate back to the main repository root. Exiting."; exit 1; }

# Deinitialize the submodule
echo "The command: git submodule deinit -f -- $SUBMODULE_PATH"
git submodule deinit -f -- $SUBMODULE_PATH

# Remove the submodule's entry from the .gitmodules file and .git/config
echo "The command: git rm -f $SUBMODULE_PATH"
git rm -f $SUBMODULE_PATH

# Clean up the submodule's files from the working tree
echo "The command: rm -rf $SUBMODULE_PATH"
rm -rf $SUBMODULE_PATH
echo "The command: rm -rf .git/modules/$SUBMODULE_PATH"
rm -rf .git/modules/$SUBMODULE_PATH

# Ensure the removal of the submodule is committed before adding the subtree
echo "The command: git commit -m 'Remove the submodule $SUBMODULE_PATH'"
git commit -m "Remove the submodule $SUBMODULE_PATH"

# Add the submodule's repository as a subtree to the current repository
# Remove the leading './' from SUBMODULE_PATH if it exists
SUBMODULE_PATH="${SUBMODULE_PATH#./}"

echo "The command: git subtree add --prefix=$SUBMODULE_PATH $SUBMODULE_URL $SUBMODULE_BRANCH"
git subtree add --prefix="$SUBMODULE_PATH" "$SUBMODULE_URL" "$SUBMODULE_BRANCH"
echo "Submodule to subtree conversion completed."
