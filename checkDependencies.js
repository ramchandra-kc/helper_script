const fs = require('fs');
const path = require('path');

function readPackageJson(rootFolder) {
  return new Promise((resolve, reject) => {
    fs.readFile(path.join(rootFolder, 'package.json'), 'utf8', (err, data) => {
      if (err) reject(err);
      else resolve(JSON.parse(data));
    });
  });
}

Array.prototype.pushUnique = function (element) {
    return this.indexOf(element) == -1 ? this.push(element) : null;
}

function findFilesUsingDependencies(rootFolder, excludeFolders = ['node_modules'], dependencies) {
  const dependencyRegex = new RegExp(`['"](${Object.keys(dependencies).join('|')})['"]`, 'g');
  const filesWithDependencies = {};
  const unusedDependencies = new Set(Object.keys(dependencies));

  function searchDirectory(directory) {
    const filesAndFolders = fs.readdirSync(directory);

    for (const item of filesAndFolders) {
      const fullPath = path.join(directory, item);
      const stat = fs.statSync(fullPath);

      if (stat.isDirectory()) {
        if (!excludeFolders.includes(item)) {
          searchDirectory(fullPath);
        }
      } else if (!(/package|webeditor|.json/g).test(fullPath)) {

        const content = fs.readFileSync(fullPath, 'utf8');
        const matches = content.match(dependencyRegex);

        if (matches) {
          matches.forEach(match => {
            match = match.replace(/'|"/g,'');
            unusedDependencies.delete(match);
            if (!filesWithDependencies[match]) {
              filesWithDependencies[match] = [];
            }
            filesWithDependencies[match].pushUnique(fullPath);
          });
        }
      }
    }
  }

  searchDirectory(rootFolder);

  return { filesWithDependencies, unusedDependencies: Array.from(unusedDependencies) };
}

// Example usage:
const rootFolder = './';

readPackageJson(rootFolder)
  .then(packageJson => {
    const { dependencies } = packageJson;
    const { filesWithDependencies, unusedDependencies } = findFilesUsingDependencies(rootFolder, ['node_modules'], dependencies);
    
    console.log('Files with dependencies:', filesWithDependencies);
    console.log('Unused dependencies:', unusedDependencies);
  })
  .catch(error => {
    console.error('Error:', error);
  });
