#!/usr/bin/env node

/**
 * AutoFix fixer for updating Node.js versions in lang-node chunk
 * 
 * This fixer updates the NODE_VERSION in Dockerfile and Dockerfile.build.ubi8
 * to the latest stable version of Node.js.
 */

const fs = require('fs').promises;
const fsSync = require('fs');
const path = require('path');

// Configuration
const LANG_NODE_DIR = path.join(__dirname, '../../chunks/lang-node');
const DOCKERFILE = path.join(LANG_NODE_DIR, 'Dockerfile');
const DOCKERFILE_BUILD_UBI8 = path.join(LANG_NODE_DIR, 'Dockerfile.build.ubi8');
const NODE_VERSIONS_URL = 'https://nodejs.org/dist/index.json';
const CACHE_FILE = path.join(__dirname, '.node-versions-cache.json');
const CACHE_TTL = 24 * 60 * 60 * 1000; // 24 hours in milliseconds

// Latest Node.js version (fallback if API fails)
const FALLBACK_NODE_VERSION = '20.11.0';

/**
 * Fetch Node.js versions from official API with caching
 * @returns {Promise<string[]>} Array of stable Node.js versions
 */
async function fetchNodeVersions() {
  try {
    // Check cache first
    if (fsSync.existsSync(CACHE_FILE)) {
      const cacheStats = fsSync.statSync(CACHE_FILE);
      const cacheAge = Date.now() - cacheStats.mtime.getTime();
      
      if (cacheAge < CACHE_TTL) {
        const cachedData = JSON.parse(fsSync.readFileSync(CACHE_FILE, 'utf8'));
        console.log('Using cached Node.js versions');
        return cachedData.versions;
      }
    }

    console.log('Fetching latest Node.js versions from nodejs.org...');
    const response = await fetch(NODE_VERSIONS_URL);
    
    if (!response.ok) {
      throw new Error(`HTTP ${response.status}: ${response.statusText}`);
    }
    
    const data = await response.json();
    const versions = data
      .filter(version => !version.version.includes('rc') && !version.version.includes('beta') && !version.version.includes('nightly'))
      .map(version => version.version.replace('v', ''))
      .reverse();
    
    // Cache the results
    await fs.writeFile(CACHE_FILE, JSON.stringify({
      versions,
      timestamp: Date.now()
    }), 'utf8');
    
    console.log(`Found ${versions.length} stable Node.js versions`);
    return versions;
  } catch (error) {
    console.warn('Failed to fetch Node.js versions, using fallback:', error.message);
    return [FALLBACK_NODE_VERSION];
  }
}

exports.register = async (fixers) => {
  const versions = await fetchNodeVersions();
  
  // Register fixer for each stable version
  versions.forEach(version => {
    fixers.register({
      name: `update-node-${version}`,
      description: `Update Node.js version to ${version}`,
      execute: async () => {
        const results = await Promise.allSettled([
          updateNodeVersionInFile(DOCKERFILE, version),
          updateNodeVersionInFile(DOCKERFILE_BUILD_UBI8, version)
        ]);
        
        return results.some(result => result.status === 'fulfilled' && result.value);
      }
    });
  });
};

/**
 * Update Node.js version in a file with enhanced error handling and backup
 * @param {string} filePath - Path to the file to update
 * @param {string} newVersion - New Node.js version to set
 * @returns {Promise<boolean>} - True if file was updated, false if no changes needed
 */
async function updateNodeVersionInFile(filePath, newVersion) {
  try {
    if (!fsSync.existsSync(filePath)) {
      console.error(`File not found: ${filePath}`);
      return false;
    }

    const content = await fs.readFile(filePath, 'utf8');
    const versionRegex = /NODE_VERSION[=\s]+"?([^"]+)"?/;
    const match = content.match(versionRegex);

    if (!match) {
      console.warn(`NODE_VERSION not found in ${filePath}`);
      return false;
    }

    const currentVersion = match[1];
    if (currentVersion === newVersion) {
      console.log(`Node.js version already up-to-date in ${filePath}: ${newVersion}`);
      return false;
    }

    // Create backup before making changes
    const backupPath = `${filePath}.backup.${Date.now()}`;
    await fs.writeFile(backupPath, content, 'utf8');
    
    const updatedContent = content.replace(versionRegex, (matchStr) => {
      // Preserve the original format (with or without quotes, with or without spaces)
      const hasQuotes = matchStr.includes('"');
      const hasEquals = matchStr.includes('=');
      const hasSpaces = matchStr.includes(' ');
      
      if (hasQuotes) {
        return matchStr.replace(currentVersion, newVersion);
      } else if (hasEquals && !hasSpaces) {
        return `NODE_VERSION=${newVersion}`;
      } else if (hasEquals && hasSpaces) {
        return `NODE_VERSION= ${newVersion}`;
      } else {
        return `NODE_VERSION ${newVersion}`;
      }
    });

    // Verify the content actually changed
    if (updatedContent === content) {
      await fs.unlink(backupPath);
      return false;
    }

    await fs.writeFile(filePath, updatedContent, 'utf8');
    console.log(`Updated Node.js version in ${filePath}: ${currentVersion} -> ${newVersion}`);
    console.log(`Backup created: ${backupPath}`);
    
    return true;
  } catch (error) {
    console.error(`Error updating ${filePath}:`, error.message);
    return false;
  }
}

/**
 * Validate Node.js version format
 * @param {string} version - Version string to validate
 * @returns {boolean} - True if valid format
 */
function validateNodeVersion(version) {
  return /^\d+\.\d+(\.\d+)?$/.test(version);
}

/**
 * Get current Node.js version from file
 * @param {string} filePath - Path to the file
 * @returns {Promise<string|null>} - Current version or null if not found
 */
async function getCurrentVersion(filePath) {
  try {
    const content = await fs.readFile(filePath, 'utf8');
    const versionRegex = /NODE_VERSION[=\s]+"?([^"]+)"?/;
    const match = content.match(versionRegex);
    return match ? match[1] : null;
  } catch (error) {
    return null;
  }
}

/**
 * Main function with enhanced error handling
 */
async function main() {
  try {
    console.log('Updating Node.js versions in lang-node chunk...');
    
    // Get latest version
    const versions = await fetchNodeVersions();
    const latestVersion = versions[0];
    
    if (!validateNodeVersion(latestVersion)) {
      throw new Error(`Invalid Node.js version format: ${latestVersion}`);
    }
    
    console.log(`Target Node.js version: ${latestVersion}`);
    
    // Check current versions
    const currentVersions = await Promise.all([
      getCurrentVersion(DOCKERFILE),
      getCurrentVersion(DOCKERFILE_BUILD_UBI8)
    ]);
    
    console.log('Current versions:');
    console.log(`  ${path.basename(DOCKERFILE)}: ${currentVersions[0] || 'not found'}`);
    console.log(`  ${path.basename(DOCKERFILE_BUILD_UBI8)}: ${currentVersions[1] || 'not found'}`);
    
    // Update files in parallel
    const results = await Promise.allSettled([
      updateNodeVersionInFile(DOCKERFILE, latestVersion),
      updateNodeVersionInFile(DOCKERFILE_BUILD_UBI8, latestVersion)
    ]);
    
    const updated = results.some(result => 
      result.status === 'fulfilled' && result.value
    );
    
    // Check for any errors
    const errors = results
      .filter(result => result.status === 'rejected')
      .map(result => result.reason);
    
    if (errors.length > 0) {
      console.error('Some operations failed:');
      errors.forEach(error => console.error(`  - ${error.message}`));
    }
    
    if (updated) {
      console.log('\nNode.js version update completed successfully!');
      console.log('Please rebuild the lang-node images to use the new version.');
      console.log('\nBackup files have been created for safety.');
    } else {
      console.log('\nNo updates needed - Node.js versions are already current.');
    }
    
  } catch (error) {
    console.error('Fatal error during Node.js version update:', error.message);
    process.exit(1);
  }
}

// Run the fixer
if (require.main === module) {
  main();
}

module.exports = {
  register: exports.register,
  updateNodeVersionInFile,
  fetchNodeVersions,
  getCurrentVersion,
  validateNodeVersion,
  FALLBACK_NODE_VERSION
};
