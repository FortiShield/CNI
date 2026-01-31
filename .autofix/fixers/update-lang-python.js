#!/usr/bin/env node

/**
 * AutoFix fixer for updating Python versions in lang-python chunk
 * 
 * This fixer updates the PYTHON_VERSION in Dockerfile and Dockerfile.build.ubi8
 * to the latest stable version of Python.
 */

const fs = require('fs').promises;
const fsSync = require('fs');
const path = require('path');

// Configuration
const LANG_PYTHON_DIR = path.join(__dirname, '../../chunks/lang-python');
const DOCKERFILE = path.join(LANG_PYTHON_DIR, 'Dockerfile');
const DOCKERFILE_BUILD_UBI8 = path.join(LANG_PYTHON_DIR, 'Dockerfile.build.ubi8');
const PYTHON_VERSIONS_URL = 'https://api.github.com/repos/python/cpython/tags';
const CACHE_FILE = path.join(__dirname, '.python-versions-cache.json');
const CACHE_TTL = 24 * 60 * 60 * 1000; // 24 hours in milliseconds

// Latest Python version (fallback if API fails)
const FALLBACK_PYTHON_VERSION = '3.12.2';

/**
 * Fetch Python versions from GitHub API with caching
 * @returns {Promise<string[]>} Array of stable Python versions
 */
async function fetchPythonVersions() {
  try {
    // Check cache first
    if (fsSync.existsSync(CACHE_FILE)) {
      const cacheStats = fsSync.statSync(CACHE_FILE);
      const cacheAge = Date.now() - cacheStats.mtime.getTime();
      
      if (cacheAge < CACHE_TTL) {
        const cachedData = JSON.parse(fsSync.readFileSync(CACHE_FILE, 'utf8'));
        console.log('Using cached Python versions');
        return cachedData.versions;
      }
    }

    console.log('Fetching latest Python versions from GitHub...');
    const response = await fetch(PYTHON_VERSIONS_URL);
    
    if (!response.ok) {
      throw new Error(`HTTP ${response.status}: ${response.statusText}`);
    }
    
    const data = await response.json();
    const versions = data
      .map(tag => tag.name.replace('v', ''))
      .filter(version => /^\d+\.\d+\.\d+$/.test(version))
      .sort((a, b) => {
        const aParts = a.split('.').map(Number);
        const bParts = b.split('.').map(Number);
        for (let i = 0; i < Math.max(aParts.length, bParts.length); i++) {
          const aPart = aParts[i] || 0;
          const bPart = bParts[i] || 0;
          if (aPart !== bPart) return bPart - aPart;
        }
        return 0;
      })
      .slice(0, 20); // Get top 20 latest versions
    
    // Cache the results
    await fs.writeFile(CACHE_FILE, JSON.stringify({
      versions,
      timestamp: Date.now()
    }), 'utf8');
    
    console.log(`Found ${versions.length} Python versions`);
    return versions;
  } catch (error) {
    console.warn('Failed to fetch Python versions, using fallback:', error.message);
    return [FALLBACK_PYTHON_VERSION];
  }
}

exports.register = async (fixers) => {
  const versions = await fetchPythonVersions();
  
  // Register fixer for each stable version
  versions.forEach(version => {
    fixers.register({
      name: `update-python-${version}`,
      description: `Update Python version to ${version}`,
      execute: async () => {
        const results = await Promise.allSettled([
          updatePythonVersionInFile(DOCKERFILE, version),
          updatePythonVersionInFile(DOCKERFILE_BUILD_UBI8, version)
        ]);
        
        return results.some(result => result.status === 'fulfilled' && result.value);
      }
    });
  });
};

/**
 * Update Python version in a file with enhanced error handling and backup
 * @param {string} filePath - Path to the file to update
 * @param {string} newVersion - New Python version to set
 * @returns {Promise<boolean>} - True if file was updated, false if no changes needed
 */
async function updatePythonVersionInFile(filePath, newVersion) {
  try {
    if (!fsSync.existsSync(filePath)) {
      console.error(`File not found: ${filePath}`);
      return false;
    }

    const content = await fs.readFile(filePath, 'utf8');
    const versionRegex = /PYTHON_VERSION[=\s]+"?([^"]+)"?/;
    const match = content.match(versionRegex);

    if (!match) {
      console.warn(`PYTHON_VERSION not found in ${filePath}`);
      return false;
    }

    const currentVersion = match[1];
    if (currentVersion === newVersion) {
      console.log(`Python version already up-to-date in ${filePath}: ${newVersion}`);
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
        return `PYTHON_VERSION=${newVersion}`;
      } else if (hasEquals && hasSpaces) {
        return `PYTHON_VERSION= ${newVersion}`;
      } else {
        return `PYTHON_VERSION ${newVersion}`;
      }
    });

    // Verify the content actually changed
    if (updatedContent === content) {
      await fs.unlink(backupPath);
      return false;
    }

    await fs.writeFile(filePath, updatedContent, 'utf8');
    console.log(`Updated Python version in ${filePath}: ${currentVersion} -> ${newVersion}`);
    console.log(`Backup created: ${backupPath}`);
    
    return true;
  } catch (error) {
    console.error(`Error updating ${filePath}:`, error.message);
    return false;
  }
}

/**
 * Validate Python version format
 * @param {string} version - Version string to validate
 * @returns {boolean} - True if valid format
 */
function validatePythonVersion(version) {
  return /^\d+\.\d+(\.\d+)?$/.test(version);
}

/**
 * Get current Python version from file
 * @param {string} filePath - Path to the file
 * @returns {Promise<string|null>} - Current version or null if not found
 */
async function getCurrentVersion(filePath) {
  try {
    const content = await fs.readFile(filePath, 'utf8');
    const versionRegex = /PYTHON_VERSION[=\s]+"?([^"]+)"?/;
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
    console.log('Updating Python versions in lang-python chunk...');
    
    // Get latest version
    const versions = await fetchPythonVersions();
    const latestVersion = versions[0];
    
    if (!validatePythonVersion(latestVersion)) {
      throw new Error(`Invalid Python version format: ${latestVersion}`);
    }
    
    console.log(`Target Python version: ${latestVersion}`);
    
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
      updatePythonVersionInFile(DOCKERFILE, latestVersion),
      updatePythonVersionInFile(DOCKERFILE_BUILD_UBI8, latestVersion)
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
      console.log('\nPython version update completed successfully!');
      console.log('Please rebuild the lang-python images to use the new version.');
      console.log('\nBackup files have been created for safety.');
    } else {
      console.log('\nNo updates needed - Python versions are already current.');
    }
    
  } catch (error) {
    console.error('Fatal error during Python version update:', error.message);
    process.exit(1);
  }
}

// Run the fixer
if (require.main === module) {
  main();
}

module.exports = {
  register: exports.register,
  updatePythonVersionInFile,
  fetchPythonVersions,
  getCurrentVersion,
  validatePythonVersion,
  FALLBACK_PYTHON_VERSION
};
