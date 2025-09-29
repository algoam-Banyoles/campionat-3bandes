/**
 * 🎯 UNIVERSAL CLOUD DATABASE CONNECTOR
 * 
 * Easy-to-use tool for any AI to connect to Supabase cloud database
 * 
 * Usage Examples:
 * 1. node cloud-db-connector.cjs --list-tables
 * 2. node cloud-db-connector.cjs --query "SELECT * FROM socis LIMIT 5"
 * 3. node cloud-db-connector.cjs --table socis
 * 4. node cloud-db-connector.cjs --schema
 * 5. node cloud-db-connector.cjs --test-connection
 * 6. node cloud-db-connector.cjs --backup-schema
 * 
 * Requirements: Set environment variables PUBLIC_SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY
 */

const { createClient } = require('@supabase/supabase-js');
const fs = require('fs');

class CloudDatabaseConnector {
    constructor() {
        // Load environment variables from .env.cloud
        require('dotenv').config({ path: '.env.cloud' });
        
        this.supabaseUrl = process.env.PUBLIC_SUPABASE_URL;
        this.supabaseServiceKey = process.env.SUPABASE_SERVICE_ROLE_KEY;
        
        if (!this.supabaseUrl || !this.supabaseServiceKey) {
            console.error('❌ Missing required environment variables:');
            console.error('   PUBLIC_SUPABASE_URL:', this.supabaseUrl ? '✅ Set' : '❌ Missing');
            console.error('   SUPABASE_SERVICE_ROLE_KEY:', this.supabaseServiceKey ? '✅ Set' : '❌ Missing');
            console.error('\n💡 These should be automatically available in this workspace');
            process.exit(1);
        }

        this.supabase = createClient(this.supabaseUrl, this.supabaseServiceKey, {
            auth: {
                autoRefreshToken: false,
                persistSession: false
            }
        });

        console.log('🔗 Connected to Supabase Cloud Database');
        console.log('📍 URL:', this.supabaseUrl);
    }

    /**
     * Test database connectivity
     */
    async testConnection() {
        try {
            console.log('🔍 Testing connection...');
            
            const { data, error } = await this.supabase
                .from('socis')
                .select('count')
                .limit(1);

            if (error) {
                console.error('❌ Connection failed:', error.message);
                return false;
            }

            console.log('✅ Connection successful!');
            return true;

        } catch (error) {
            console.error('❌ Connection error:', error.message);
            return false;
        }
    }

    /**
     * List all available tables
     */
    async listTables() {
        try {
            console.log('📊 Available tables in cloud database:\n');

            // Get schema information from the API
            const response = await fetch(`${this.supabaseUrl}/rest/v1/`, {
                headers: {
                    'apikey': this.supabaseServiceKey,
                    'Authorization': `Bearer ${this.supabaseServiceKey}`
                }
            });

            const schemaText = await response.text();
            const schema = JSON.parse(schemaText);
            const definitions = schema.definitions || {};

            const tables = Object.keys(definitions)
                .filter(name => !name.startsWith('v_'))
                .sort();

            const views = Object.keys(definitions)
                .filter(name => name.startsWith('v_'))
                .sort();

            console.log('📋 TABLES:');
            tables.forEach((table, index) => {
                console.log(`  ${index + 1}. ${table}`);
            });

            if (views.length > 0) {
                console.log('\n👁️  VIEWS:');
                views.forEach((view, index) => {
                    console.log(`  ${index + 1}. ${view}`);
                });
            }

            console.log(`\n📊 Total: ${tables.length} tables, ${views.length} views`);
            return { tables, views };

        } catch (error) {
            console.error('❌ Failed to list tables:', error.message);
            return null;
        }
    }

    /**
     * Execute a custom SQL query via RPC
     */
    async executeQuery(query) {
        try {
            console.log('🔍 Executing query:', query);
            console.log('⚠️  Note: For security, only SELECT queries are recommended');

            // For simple SELECT queries, we can try to parse and use the REST API
            if (query.toLowerCase().trim().startsWith('select')) {
                const tableMatch = query.match(/from\s+(\w+)/i);
                if (tableMatch) {
                    const tableName = tableMatch[1];
                    console.log(`📋 Querying table: ${tableName}`);
                    
                    const { data, error } = await this.supabase
                        .from(tableName)
                        .select('*')
                        .limit(100); // Safety limit

                    if (error) {
                        console.error('❌ Query failed:', error.message);
                        return null;
                    }

                    console.log('✅ Query successful!');
                    console.log('📊 Results:', JSON.stringify(data, null, 2));
                    return data;
                }
            }

            console.log('⚠️  Complex queries not supported via REST API');
            console.log('💡 Use --table <tablename> for simple data access');
            return null;

        } catch (error) {
            console.error('❌ Query execution failed:', error.message);
            return null;
        }
    }

    /**
     * Get data from a specific table
     */
    async getTableData(tableName, limit = 10) {
        try {
            console.log(`📋 Getting data from table: ${tableName}`);
            console.log(`📊 Limit: ${limit} rows`);

            const { data, error } = await this.supabase
                .from(tableName)
                .select('*')
                .limit(limit);

            if (error) {
                console.error('❌ Failed to get table data:', error.message);
                return null;
            }

            console.log('✅ Data retrieved successfully!');
            console.log('📊 Results:');
            console.log(JSON.stringify(data, null, 2));
            
            if (data.length === limit) {
                console.log(`\n💡 Showing first ${limit} rows. Use --limit for more.`);
            }

            return data;

        } catch (error) {
            console.error('❌ Failed to get table data:', error.message);
            return null;
        }
    }

    /**
     * Get complete database schema
     */
    async getSchema() {
        try {
            console.log('🔍 Getting complete database schema...');

            const response = await fetch(`${this.supabaseUrl}/rest/v1/`, {
                headers: {
                    'apikey': this.supabaseServiceKey,
                    'Authorization': `Bearer ${this.supabaseServiceKey}`
                }
            });

            const schemaText = await response.text();
            const schema = JSON.parse(schemaText);

            console.log('✅ Schema retrieved successfully!');
            console.log('📊 Schema structure:');
            console.log(JSON.stringify(schema.definitions, null, 2));

            return schema;

        } catch (error) {
            console.error('❌ Failed to get schema:', error.message);
            return null;
        }
    }

    /**
     * Backup schema to file
     */
    async backupSchema() {
        try {
            console.log('💾 Creating schema backup...');

            const schema = await this.getSchema();
            if (!schema) return false;

            const timestamp = new Date().toISOString().replace(/[-:T]/g, '').split('.')[0];
            const filename = `schema-backup-${timestamp}.json`;

            fs.writeFileSync(filename, JSON.stringify(schema, null, 2));

            console.log(`✅ Schema backup created: ${filename}`);
            return true;

        } catch (error) {
            console.error('❌ Failed to create backup:', error.message);
            return false;
        }
    }

    /**
     * Show help information
     */
    showHelp() {
        console.log(`
🎯 CLOUD DATABASE CONNECTOR - Help

📋 Available Commands:
  --test-connection     Test database connectivity
  --list-tables        Show all available tables and views
  --table <name>       Get data from specific table (default: 10 rows)
  --query "<sql>"      Execute SELECT query (limited support)
  --schema             Show complete database schema
  --backup-schema      Create schema backup file
  --limit <number>     Set row limit for table queries
  --help               Show this help

🔧 Usage Examples:
  node cloud-db-connector.cjs --test-connection
  node cloud-db-connector.cjs --list-tables
  node cloud-db-connector.cjs --table socis
  node cloud-db-connector.cjs --table players --limit 20
  node cloud-db-connector.cjs --query "SELECT nom, email FROM socis LIMIT 5"
  node cloud-db-connector.cjs --schema
  node cloud-db-connector.cjs --backup-schema

📊 Common Tables:
  • socis - Club members
  • events - Championships/tournaments  
  • players - Active players
  • challenges - Match challenges
  • matches - Played matches
  • ranking_positions - Current rankings
  • categories - Competition categories

💡 Tips:
  • All operations are READ-ONLY for safety
  • Use --limit to control number of rows returned
  • Schema backup includes complete table definitions
  • Environment variables are automatically loaded

🔗 Database: ${this.supabaseUrl}
        `);
    }
}

// Command line interface
async function main() {
    const args = process.argv.slice(2);
    
    if (args.length === 0 || args.includes('--help')) {
        const connector = new CloudDatabaseConnector();
        connector.showHelp();
        return;
    }

    try {
        const connector = new CloudDatabaseConnector();

        if (args.includes('--test-connection')) {
            await connector.testConnection();
        
        } else if (args.includes('--list-tables')) {
            await connector.listTables();
        
        } else if (args.includes('--schema')) {
            await connector.getSchema();
        
        } else if (args.includes('--backup-schema')) {
            await connector.backupSchema();
        
        } else if (args.includes('--table')) {
            const tableIndex = args.indexOf('--table');
            const tableName = args[tableIndex + 1];
            
            if (!tableName) {
                console.error('❌ Table name required. Usage: --table <tablename>');
                return;
            }

            let limit = 10;
            if (args.includes('--limit')) {
                const limitIndex = args.indexOf('--limit');
                limit = parseInt(args[limitIndex + 1]) || 10;
            }

            await connector.getTableData(tableName, limit);
        
        } else if (args.includes('--query')) {
            const queryIndex = args.indexOf('--query');
            const query = args[queryIndex + 1];
            
            if (!query) {
                console.error('❌ Query required. Usage: --query "SELECT ..."');
                return;
            }

            await connector.executeQuery(query);
        
        } else {
            console.log('❌ Unknown command. Use --help for available options.');
            connector.showHelp();
        }

    } catch (error) {
        console.error('❌ Application error:', error.message);
        process.exit(1);
    }
}

// Export for programmatic use
module.exports = CloudDatabaseConnector;

// Run if called directly
if (require.main === module) {
    main();
}