#!/usr/bin/env node

/**
 * AutoFix fixer for updating C++ (GCC) versions in lang-cpp chunk
 * 
 * This fixer updates the GCC_VERSION in Dockerfile and Dockerfile.build.ubi8
 * to the latest stable version of GCC.
 */

const fs = require('fs').promises;
const fsSync = require('fs');
const path = require('path');

// Configuration
const LANG_CPP_DIR = path.join(__dirname, '../../chunks/lang-cpp');
const DOCKERFILE = path.join(LANG_CPP_DIR, 'Dockerfile');
const DOCKERFILE_BUILD_UBI8 = path.join(LANG_CPP_DIR, 'Dockerfile.build.ubi8');
const GCC_VERSIONS_URL = 'https://api.github.com/repos/gcc-mirror/gcc/releases';
const CACHE_FILE = path.join(__dirname, '.cpp-versions-cache.json');
const CACHE_TTL = 24 * 60 * 60 * 1000; // 24 hours in milliseconds

// Latest GCC version (fallback if API fails)
const FALLBACK_GCC_VERSION = '13.2.0';

/**
 * Fetch GCC versions from GitHub API with caching
 * @returns {Promise<string[]>} Array of stable GCC versions
 */
async function fetchCppVersions() {
  try {
    // Check cache first
    if (fsSync.existsSync(CACHE_FILE)) {
      const cacheStats = fsSync.statSync(CACHE_FILE);
      const cacheAge = Date.now() - cacheStats.mtime.getTime();
      
      if (cacheAge < CACHE_TTL) {
        const cachedData = JSON.parse(fsSync.readFileSync(CACHE_FILE, 'utf8'));
        console.log('Using cached C++ versions');
        return cachedData.versions;
      }
    }

    console.log('Fetching latest GCC versions from GitHub...');
    const response = await fetch(GCC_VERSIONS_URL);
    
    if (!response.ok) {
      throw new Error(`HTTP ${response.status}: ${response.statusText}`);
    }
    
    const data = await response.json();
    const versions = data
      .filter(release => !release.prerelease && !release.draft && 
        release.tag_name.startsWith('releases/gcc-'))
      .map(release => {
        const tag = release.tag_name;
        // Extract version number from tags like "releases/gcc-13.2.0"
        const match = tag.match(/releases\/gcc-(\d+\.\d+(?:\.\d+)?)/);
        return match ? match[1] : null;
      })
      .filter(version => version !== null)
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
      .slice(0, 20); // Get top 20 latest stable versions
    
    // Cache the results
    await fs.writeFile(CACHE_FILE, JSON.stringify({
      versions,
      timestamp: Date.now()
    }), 'utf8');
    
    console.log(`Found ${versions.length} stable GCC versions`);
    return versions;
  } catch (error) {
    console.warn('Failed to fetch GCC versions, using fallback:', error.message);
    return [FALLBACK_GCC_VERSION];
  }
}

exports.register = async (fixers) => {
  const versions = await fetchCppVersions();
  
  // Register fixer for each stable version
  versions.forEach(version => {
    fixers.register({
      name: `update-cpp-${version}`,
      description: `Update C++ (GCC) version to ${version}`,
      execute: async () => {
        const results = await Promise.allSettled([
          updateCppVersionInFile(DOCKERFILE, version),
          updateCppVersionInFile(DOCKERFILE_BUILD_UBI8, version)
        ]);
        
        return results.some(result => result.status === 'fulfilled' && result.value);
      }
    });
  });
};

/**
 * Update C++ (GCC) version in a file with enhanced error handling and backup
 * @param {string} filePath - Path to the file to update
 * @param {string} newVersion - New GCC version to set
 * @returns {Promise<boolean>} - True if file was updated, false if no changes needed
 */
async function updateCppVersionInFile(filePath, newVersion) {
  try {
    if (!fsSync.existsSync(filePath)) {
      console.error(`File not found: ${filePath}`);
      return false;
    }

    const content = await fs.readFile(filePath, 'utf8');
    const versionRegex = /GCC_VERSION[=\s]+"?([^"]+)"?/;
    const match = content.match(versionRegex);

    if (!match) {
      console.warn(`GCC_VERSION not found in ${filePath}`);
      return false;
    }

    const currentVersion = match[1];
    if (currentVersion === newVersion) {
      console.log(`C++ (GCC) version already up-to-date in ${filePath}: ${newVersion}`);
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
        return `GCC_VERSION=${newVersion}`;
      } else if (hasEquals && hasSpaces) {
        return `GCC_VERSION= ${newVersion}`;
      } else {
        return `GCC_VERSION ${newVersion}`;
      }
    });

    // Verify the content actually changed
    if (updatedContent === content) {
      await fs.unlink(backupPath);
      return false;
    }

    await fs.writeFile(filePath, updatedContent, 'utf8');
    console.log(`Updated C++ (GCC) version in ${filePath}: ${currentVersion} -> ${newVersion}`);
    console.log(`Backup created: ${backupPath}`);
    
    return true;
  } catch (error) {
    console.error(`Error updating ${filePath}:`, error.message);
    return false;
  }
}

/**
 * Validate C++ (GCC) version format
 * @param {string} version - Version string to validate
 * @returns {boolean} - True if valid format
 */
function validateCppVersion(version) {
  return /^\d+\.\d+(\.\d+)?$/.test(version);
}

/**
 * Get current C++ (GCC) version from file
 * @param {string} filePath - Path to the file
 * @returns {Promise<string|null>} - Current version or null if not found
 */
async function getCurrentVersion(filePath) {
  try {
    const content = await fs.readFile(filePath, 'utf8');
    const versionRegex = /GCC_VERSION[=\s]+"?([^"]+)"?/;
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
    console.log('Updating C++ (GCC) versions in lang-cpp chunk...');
    
    // Get latest version
    const versions = await fetchCppVersions();
    const latestVersion = versions[0];
    
    if (!validateCppVersion(latestVersion)) {
      throw new Error(`Invalid C++ (GCC) version format: ${latestVersion}`);
    }
    
    console.log(`Target C++ (GCC) version: ${latestVersion}`);
    
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
      updateCppVersionInFile(DOCKERFILE, latestVersion),
      updateCppVersionInFile(DOCKERFILE_BUILD_UBI8, latestVersion)
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
      console.log('\nC++ (GCC) version update completed successfully!');
      console.log('Please rebuild the lang-cpp images to use the new version.');
      console.log('\nBackup files have been created for safety.');
    } else {
      console.log('\nNo updates needed - C++ (GCC) versions are already current.');
    }
    
  } catch (error) {
    console.error('Fatal error during C++ (GCC) version update:', error.message);
    process.exit(1);
  }
}

// Run the fixer
if (require.main === module) {
  main();
}

module.exports = {
  register: exports.register,
  updateCppVersionInFile,
  fetchCppVersions,
  getCurrentVersion,
  validateCppVersion,
  FALLBACK_GCC_VERSION
};
