const fs = require('fs');
const { Transform } = require('stream');
const { program } = require('commander');

program
  .option('-i, --input <type>', 'input file to parse')
  .option('-o, --output <type>', 'output file to write to')
  .option('-h, --help', 'showing the available arguments on how to use the code');

program.parse(process.argv);

const options = program.opts();
if (options.help) {
  program.help();
}

const inputFile = options.input;
if (!inputFile) {
    console.error("Please provide input file to format.");
    process.exit(0);
}
const outputFile = options.output || options.inputFile + '.output';


/**
 * Creates a read stream, modifies the data by adding a new line after every closing tag (</anyTag>),
 * and writes the modified data to a new file using a write stream.
 * 
 * @param {string} inputFile - The path of the input file.
 * @param {string} outputFile - The path of the output file.
 */
function processFile(inputFile, outputFile) {
    const readStream = fs.createReadStream(inputFile, { encoding: 'utf8' });
    const writeStream = fs.createWriteStream(outputFile, { encoding: 'utf8' });

    const transformStream = new Transform({
        transform(chunk, encoding, callback) {
            // Convert chunk to string and replace '</anyTag>' with '</anyTag>\n' to add a new line
            const modifiedChunk = chunk.toString().replace(/(<\/[\w\s-]*>)/g, '$1\n');
            this.push(modifiedChunk);
            callback();
        }
    });

    readStream
        .pipe(transformStream) // Pass data through the transform stream to modify it
        .pipe(writeStream) // Write the modified data to the output file
        .on('finish', () => console.log('File processing completed.'));
}

// Example usage
processFile(inputFile, outputFile);
