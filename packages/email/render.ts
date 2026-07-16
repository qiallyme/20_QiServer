import * as fs from 'fs';
import * as path from 'path';

const emailDir = __dirname;
const partialsDir = path.join(emailDir, 'partials');
const supabaseAuthDir = path.join(emailDir, 'supabase-auth');
const templatesDir = path.join(emailDir, 'templates');
const distDir = path.join(emailDir, 'compiled');

// Read partials
const header = fs.readFileSync(path.join(partialsDir, 'header.html'), 'utf8');
const footer = fs.readFileSync(path.join(partialsDir, 'footer.html'), 'utf8');

// Ensure output directories exist
if (!fs.existsSync(distDir)) {
  fs.mkdirSync(distDir);
}
const distSupabaseAuthDir = path.join(distDir, 'supabase-auth');
if (!fs.existsSync(distSupabaseAuthDir)) {
  fs.mkdirSync(distSupabaseAuthDir);
}

function compileContent(content: string): string {
  let compiled = content;
  // Replace header and footer templates
  compiled = compiled.replace(/\{\{\s*template\s+"header\.html"\s+\.\s*\}\}/g, header);
  compiled = compiled.replace(/\{\{\s*template\s+"footer\.html"\s+\.\s*\}\}/g, footer);
  return compiled;
}

// Compile supabase-auth templates
const supabaseAuthFiles = fs.readdirSync(supabaseAuthDir);
for (const file of supabaseAuthFiles) {
  if (file.endsWith('.html')) {
    const filePath = path.join(supabaseAuthDir, file);
    const content = fs.readFileSync(filePath, 'utf8');
    
    // Check if it's already standalone or uses template partials
    let compiled = content;
    if (content.includes('template "header.html"')) {
      compiled = compileContent(content);
    } else {
      // It is already a standalone template, copy it to the compiled directory
      compiled = content;
    }
    
    fs.writeFileSync(path.join(distSupabaseAuthDir, file), compiled, 'utf8');
    console.log(`Compiled supabase-auth template: ${file}`);
  }
}

// Compile general templates
const generalDir = path.join(templatesDir, 'general');
const distGeneralDir = path.join(distDir, 'templates', 'general');
if (fs.existsSync(generalDir)) {
  if (!fs.existsSync(path.dirname(distGeneralDir))) {
    fs.mkdirSync(path.dirname(distGeneralDir));
  }
  if (!fs.existsSync(distGeneralDir)) {
    fs.mkdirSync(distGeneralDir);
  }
  const generalFiles = fs.readdirSync(generalDir);
  for (const file of generalFiles) {
    if (file.endsWith('.html')) {
      const content = fs.readFileSync(path.join(generalDir, file), 'utf8');
      const compiled = compileContent(content);
      fs.writeFileSync(path.join(distGeneralDir, file), compiled, 'utf8');
      console.log(`Compiled general template: ${file}`);
    }
  }
}

console.log('Template compilation completed successfully.');
