#!/usr/bin/env node

/**
 * AutoFix fixer for updating C# (.NET) versions in lang-csharp chunk
 * 
 * This fixer updates the DOTNET_VERSION in Dockerfile and Dockerfile.build.ubi8
 * to the latest stable version of .NET.
 */

const fs = require('fs').promises;
const fsSync = require('fs');
const path = require('path');

// Configuration
const LANG_CSHARP_DIR = path.join(__dirname, '../../chunks/lang-csharp');
const DOCKERFILE = path.join(LANG_CSHARP_DIR, 'Dockerfile');
const DOCKERFILE_BUILD_UBI8 = path.join(LANG_CSHARP_DIR, 'Dockerfile.build.ubi8');
const DOTNET_VERSIONS_URL = 'https://api.github.com/repos/dotnet/runtime/releases';
const CACHE_FILE = path.join(__dirname, '.csharp-versions-cache.json');
const CACHE_TTL = 24 * 60 * 60 * 1000; // 24 hours in milliseconds

// Latest .NET version (fallback if API fails)
const FALLBACK_DOTNET_VERSION = '8.0.3';

/**
 * Fetch .NET versions from GitHub API with caching
 * @returns {Promise<string[]>} Array of stable .NET versions
 */
async function fetchCsharpVersions() {
  try {
    // Check cache first
    if (fsSync.existsSync(CACHE_FILE)) {
      const cacheStats = fsSync.statSync(CACHE_FILE);
      const cacheAge = Date.now() - cacheStats.mtime.getTime();
      
      if (cacheAge < CACHE_TTL) {
        const cachedData = JSON.parse(fsSync.readFileSync(CACHE_FILE, 'utf8'));
        console.log('Using cached C# versions');
        return cachedData.versions;
      }
    }

    console.log('Fetching latest .NET versions from GitHub...');
    const response = await fetch(DOTNET_VERSIONS_URL);
    
    if (!response.ok) {
      throw new Error(`HTTP ${response.status}: ${response.statusText}`);
    }
    
    const data = await response.json();
    const versions = data
      .filter(release => !release.prerelease && !release.draft && 
        (release.tag_name.startsWith('v') || release.tag_name.match(/^\d+\.\d+\.\d+$/)))
      .map(release => {
        const tag = release.tag_name;
        // Extract version number from tags like "v8.0.3" or "8.0.3"
        if (tag.startsWith('v')) {
          return tag.substring(1);
        }
        return tag;
      })
      .filter(version => /^\d+\.\d+(\.\d+)?$/.test(version))
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
    
    console.log(`Found ${versions.length} stable .NET versions`);
    return versions;
  } catch (error) {
    console.warn('Failed to fetch .NET versions, using fallback:', error.message);
    return [FALLBACK_DOTNET_VERSION];
  }
}

exports.register = async (fixers) => {
  const versions = await fetchCsharpVersions();
  
  // Register fixer for each stable version
  versions.forEach(version => {
    fixers.register({
      name: `update-csharp-${version}`,
      description: `Update C# (.NET) version to ${version}`,
      execute: async () => {
        const results = await Promise.allSettled([
          updateCsharpVersionInFile(DOCKERFILE, version),
          updateCsharpVersionInFile(DOCKERFILE_BUILD_UBI8, version)
        ]);
        
        return results.some(result => result.status === 'fulfilled' && result.value);
      }
    });
  });
};

/**
 * Update C# (.NET) version in a file with enhanced error handling and backup
 * @param {string} filePath - Path to the file to update
 * @param {string} newVersion - New .NET version to set
 * @returns {Promise<boolean>} - True if file was updated, false if no changes needed
 */
async function updateCsharpVersionInFile(filePath, newVersion) {
  try {
    if (!fsSync.existsSync(filePath)) {
      console.error(`File not found: ${filePath}`);
      return false;
    }

    const content = await fs.readFile(filePath, 'utf8');
    const versionRegex = /DOTNET_VERSION[=\s]+"?([^"]+)"?/;
    const match = content.match(versionRegex);

    if (!match) {
      console.warn(`DOTNET_VERSION not found in ${filePath}`);
      return false;
    }

    const currentVersion = match[1];
    if (currentVersion === newVersion) {
      console.log(`C# (.NET) version already up-to-date in ${filePath}: ${newVersion}`);
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
        return `DOTNET_VERSION=${newVersion}`;
      } else if (hasEquals && hasSpaces) {
        return `DOTNET_VERSION= ${newVersion}`;
      } else {
        return `DOTNET_VERSION ${newVersion}`;
      }
    });

    // Verify the content actually changed
    if (updatedContent === content) {
      await fs.unlink(backupPath);
      return false;
    }

    await fs.writeFile(filePath, updatedContent, 'utf8');
    console.log(`Updated C# (.NET) version in ${filePath}: ${currentVersion} -> ${newVersion}`);
    console.log(`Backup created: ${backupPath}`);
    
    return true;
  } catch (error) {
    console.error(`Error updating ${filePath}:`, error.message);
    return false;
  }
}

/**
 * Validate C# (.NET) version format
 * @param {string} version - Version string to validate
 * @returns {boolean} - True if valid format
 */
function validateCsharpVersion(version) {
  return /^\d+\.\d+(\.\d+)?$/.test(version);
}

/**
 * Get current C# (.NET) version from file
 * @param {string} filePath - Path to the file
 * @returns {Promise<string|null>} - Current version or null if not found
 */
async function getCurrentVersion(filePath) {
  try {
    const content = await fs.readFile(filePath, 'utf8');
    const versionRegex = /DOTNET_VERSION[=\s]+"?([^"]+)"?/;
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
    console.log('Updating C# (.NET) versions in lang-csharp chunk...');
    
    // Get latest version
    const versions = await fetchCsharpVersions();
    const latestVersion = versions[0];
    
    if (!validateCsharpVersion(latestVersion)) {
      throw new Error(`Invalid C# (.NET) version format: ${latestVersion}`);
    }
    
    console.log(`Target C# (.NET) version: ${latestVersion}`);
    
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
      updateCsharpVersionInFile(DOCKERFILE, latestVersion),
      updateCsharpVersionInFile(DOCKERFILE_BUILD_UBI8, latestVersion)
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
      console.log('\nC# (.NET) version update completed successfully!');
      console.log('Please rebuild the lang-csharp images to use the new version.');
      console.log('\nBackup files have been created for safety.');
    } else {
      console.log('\nNo updates needed - C# (.NET) versions are already current.');
    }
    
  } catch (error) {
    console.error('Fatal error during C# (.NET) version update:', error.message);
    process.exit(1);
  }
}

// Run the fixer
if (require.main === module) {
  main();
}

module.exports = {
  register: exports.register,
  updateCsharpVersionInFile,
  fetchCsharpVersions,
  getCurrentVersion,
  validateCsharpVersion,
  FALLBACK_DOTNET_VERSION
};
