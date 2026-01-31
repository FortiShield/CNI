#!/usr/bin/env node

/**
 * AutoFix fixer for updating Java versions in lang-java chunk
 * 
 * This fixer updates the JAVA_VERSION in Dockerfile and Dockerfile.build.ubi8
 * to the latest stable version of Java.
 */

const fs = require('fs').promises;
const fsSync = require('fs');
const path = require('path');

// Configuration
const LANG_JAVA_DIR = path.join(__dirname, '../../chunks/lang-java');
const DOCKERFILE = path.join(LANG_JAVA_DIR, 'Dockerfile');
const DOCKERFILE_BUILD_UBI8 = path.join(LANG_JAVA_DIR, 'Dockerfile.build.ubi8');
const JAVA_VERSIONS_URL = 'https://api.github.com/repos/openjdk/jdk/releases';
const CACHE_FILE = path.join(__dirname, '.java-versions-cache.json');
const CACHE_TTL = 24 * 60 * 60 * 1000; // 24 hours in milliseconds

// Latest Java version (fallback if API fails)
const FALLBACK_JAVA_VERSION = '21';

/**
 * Fetch Java versions from GitHub API with caching
 * @returns {Promise<string[]>} Array of stable Java versions
 */
async function fetchJavaVersions() {
  try {
    // Check cache first
    if (fsSync.existsSync(CACHE_FILE)) {
      const cacheStats = fsSync.statSync(CACHE_FILE);
      const cacheAge = Date.now() - cacheStats.mtime.getTime();
      
      if (cacheAge < CACHE_TTL) {
        const cachedData = JSON.parse(fsSync.readFileSync(CACHE_FILE, 'utf8'));
        console.log('Using cached Java versions');
        return cachedData.versions;
      }
    }

    console.log('Fetching latest Java versions from GitHub...');
    const response = await fetch(JAVA_VERSIONS_URL);
    
    if (!response.ok) {
      throw new Error(`HTTP ${response.status}: ${response.statusText}`);
    }
    
    const data = await response.json();
    const versions = data
      .filter(release => !release.prerelease && !release.draft && 
        (release.tag_name.includes('jdk-') || release.tag_name.startsWith('jdk')))
      .map(release => {
        const tag = release.tag_name;
        // Extract version number from tags like "jdk-21.0.2-ga" or "jdk21.0.2"
        const match = tag.match(/jdk-?(\d+)(?:\.(\d+))?(?:\.(\d+))?/);
        if (match) {
          const major = match[1];
          const minor = match[2] || '0';
          const patch = match[3] || '0';
          // Return major version for compatibility with current setup
          return major;
        }
        return null;
      })
      .filter(version => version !== null)
      .map(version => version.toString())
      .sort((a, b) => parseInt(b) - parseInt(a))
      .filter((version, index, self) => self.indexOf(version) === index) // Remove duplicates
      .slice(0, 10); // Get top 10 latest major versions
    
    // Cache the results
    await fs.writeFile(CACHE_FILE, JSON.stringify({
      versions,
      timestamp: Date.now()
    }), 'utf8');
    
    console.log(`Found ${versions.length} Java versions`);
    return versions;
  } catch (error) {
    console.warn('Failed to fetch Java versions, using fallback:', error.message);
    return [FALLBACK_JAVA_VERSION];
  }
}

exports.register = async (fixers) => {
  const versions = await fetchJavaVersions();
  
  // Register fixer for each stable version
  versions.forEach(version => {
    fixers.register({
      name: `update-java-${version}`,
      description: `Update Java version to ${version}`,
      execute: async () => {
        const results = await Promise.allSettled([
          updateJavaVersionInFile(DOCKERFILE, version),
          updateJavaVersionInFile(DOCKERFILE_BUILD_UBI8, version)
        ]);
        
        return results.some(result => result.status === 'fulfilled' && result.value);
      }
    });
  });
};

/**
 * Update Java version in a file with enhanced error handling and backup
 * @param {string} filePath - Path to the file to update
 * @param {string} newVersion - New Java version to set
 * @returns {Promise<boolean>} - True if file was updated, false if no changes needed
 */
async function updateJavaVersionInFile(filePath, newVersion) {
  try {
    if (!fsSync.existsSync(filePath)) {
      console.error(`File not found: ${filePath}`);
      return false;
    }

    const content = await fs.readFile(filePath, 'utf8');
    const versionRegex = /JAVA_VERSION[=\s]+"?([^"]+)"?/;
    const match = content.match(versionRegex);

    if (!match) {
      console.warn(`JAVA_VERSION not found in ${filePath}`);
      return false;
    }

    const currentVersion = match[1];
    if (currentVersion === newVersion) {
      console.log(`Java version already up-to-date in ${filePath}: ${newVersion}`);
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
        return `JAVA_VERSION=${newVersion}`;
      } else if (hasEquals && hasSpaces) {
        return `JAVA_VERSION= ${newVersion}`;
      } else {
        return `JAVA_VERSION ${newVersion}`;
      }
    });

    // Verify the content actually changed
    if (updatedContent === content) {
      await fs.unlink(backupPath);
      return false;
    }

    await fs.writeFile(filePath, updatedContent, 'utf8');
    console.log(`Updated Java version in ${filePath}: ${currentVersion} -> ${newVersion}`);
    console.log(`Backup created: ${backupPath}`);
    
    return true;
  } catch (error) {
    console.error(`Error updating ${filePath}:`, error.message);
    return false;
  }
}

/**
 * Validate Java version format
 * @param {string} version - Version string to validate
 * @returns {boolean} - True if valid format
 */
function validateJavaVersion(version) {
  return /^\d+$/.test(version);
}

/**
 * Get current Java version from file
 * @param {string} filePath - Path to the file
 * @returns {Promise<string|null>} - Current version or null if not found
 */
async function getCurrentVersion(filePath) {
  try {
    const content = await fs.readFile(filePath, 'utf8');
    const versionRegex = /JAVA_VERSION[=\s]+"?([^"]+)"?/;
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
    console.log('Updating Java versions in lang-java chunk...');
    
    // Get latest version
    const versions = await fetchJavaVersions();
    const latestVersion = versions[0];
    
    if (!validateJavaVersion(latestVersion)) {
      throw new Error(`Invalid Java version format: ${latestVersion}`);
    }
    
    console.log(`Target Java version: ${latestVersion}`);
    
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
      updateJavaVersionInFile(DOCKERFILE, latestVersion),
      updateJavaVersionInFile(DOCKERFILE_BUILD_UBI8, latestVersion)
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
      console.log('\nJava version update completed successfully!');
      console.log('Please rebuild the lang-java images to use the new version.');
      console.log('\nBackup files have been created for safety.');
    } else {
      console.log('\nNo updates needed - Java versions are already current.');
    }
    
  } catch (error) {
    console.error('Fatal error during Java version update:', error.message);
    process.exit(1);
  }
}

// Run the fixer
if (require.main === module) {
  main();
}

module.exports = {
  register: exports.register,
  updateJavaVersionInFile,
  fetchJavaVersions,
  getCurrentVersion,
  validateJavaVersion,
  FALLBACK_JAVA_VERSION
};
