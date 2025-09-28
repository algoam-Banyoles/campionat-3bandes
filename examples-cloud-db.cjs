/**
 * 🎯 EXEMPLE D'ÚS PROGRAMÀTIC DEL CLOUD DATABASE CONNECTOR
 * 
 * Aquest fitxer mostra com usar el CloudDatabaseConnector programàticament
 * des d'altres scripts o aplicacions.
 */

const CloudDatabaseConnector = require('./cloud-db-connector.cjs');

async function exempleCompletAnalisiDades() {
    console.log('🚀 Iniciant anàlisi complet de dades...\n');

    try {
        // Crear instància del connector
        const db = new CloudDatabaseConnector();

        // 1. Verificar connexió
        console.log('1️⃣ Verificant connexió...');
        const isConnected = await db.testConnection();
        if (!isConnected) {
            console.error('❌ No es pot connectar a la base de dades');
            return;
        }

        // 2. Obtenir llista de taules
        console.log('\n2️⃣ Obtenint llista de taules...');
        const tablesInfo = await db.listTables();
        console.log(`📊 Trobades ${tablesInfo.tables.length} taules i ${tablesInfo.views.length} vistes`);

        // 3. Analitzar dades dels socis
        console.log('\n3️⃣ Analitzant socis...');
        const socis = await db.getTableData('socis', 50);
        if (socis) {
            const socisActius = socis.filter(s => !s.de_baixa);
            console.log(`👥 Socis actius: ${socisActius.length}/${socis.length}`);
        }

        // 4. Analitzar events actius
        console.log('\n4️⃣ Analitzant events...');
        const events = await db.getTableData('events', 20);
        if (events) {
            const eventsActius = events.filter(e => e.actiu);
            console.log(`🏆 Events actius: ${eventsActius.length}/${events.length}`);
            
            if (eventsActius.length > 0) {
                console.log('📋 Events actius:');
                eventsActius.forEach(event => {
                    console.log(`   • ${event.nom} (${event.temporada})`);
                });
            }
        }

        // 5. Analitzar players
        console.log('\n5️⃣ Analitzant jugadors...');
        const players = await db.getTableData('players', 30);
        if (players) {
            const playersActius = players.filter(p => p.estat === 'actiu');
            console.log(`🎮 Jugadors actius: ${playersActius.length}/${players.length}`);
            
            const playersAmbMitjana = players.filter(p => p.mitjana && p.mitjana > 0);
            if (playersAmbMitjana.length > 0) {
                const mitjanaTotal = playersAmbMitjana.reduce((sum, p) => sum + parseFloat(p.mitjana), 0) / playersAmbMitjana.length;
                console.log(`📊 Mitjana general: ${mitjanaTotal.toFixed(2)}`);
            }
        }

        // 6. Crear backup de l'esquema
        console.log('\n6️⃣ Creant backup de l\'esquema...');
        await db.backupSchema();

        console.log('\n✅ Anàlisi completat amb èxit!');

    } catch (error) {
        console.error('❌ Error durant l\'anàlisi:', error.message);
    }
}

async function exempleConsultesEspecifiques() {
    console.log('\n🔍 Exemples de consultes específiques...\n');

    const db = new CloudDatabaseConnector();

    try {
        // Exemple 1: Obtenir reptes pendents
        console.log('📋 Reptes recents...');
        const challenges = await db.getTableData('challenges', 5);
        if (challenges && challenges.length > 0) {
            console.log('Últims reptes:');
            challenges.forEach(challenge => {
                console.log(`   • Estat: ${challenge.estat} (${challenge.data_proposta?.substring(0, 10)})`);
            });
        }

        // Exemple 2: Configuració de l'aplicació
        console.log('\n⚙️ Configuració actual...');
        const settings = await db.getTableData('app_settings', 1);
        if (settings && settings.length > 0) {
            const config = settings[0];
            console.log(`   • Caramboles objectiu: ${config.caramboles_objectiu}`);
            console.log(`   • Max entrades: ${config.max_entrades}`);
            console.log(`   • Cooldown dies: ${config.cooldown_min_dies}-${config.cooldown_max_dies}`);
        }

        // Exemple 3: Categories disponibles
        console.log('\n🏅 Categories...');
        const categories = await db.getTableData('categories', 10);
        if (categories && categories.length > 0) {
            console.log('Categories trobades:');
            categories.forEach(cat => {
                console.log(`   • ${cat.nom}: ${cat.distancia_caramboles} caramboles`);
            });
        }

    } catch (error) {
        console.error('❌ Error en consultes específiques:', error.message);
    }
}

// Funcions d'utilitat per a IAs
async function getQuickStats() {
    const db = new CloudDatabaseConnector();
    
    try {
        const socis = await db.getTableData('socis', 100);
        const players = await db.getTableData('players', 100);
        const challenges = await db.getTableData('challenges', 50);
        const events = await db.getTableData('events', 20);

        return {
            total_socis: socis?.length || 0,
            socis_actius: socis?.filter(s => !s.de_baixa)?.length || 0,
            total_players: players?.length || 0,
            players_actius: players?.filter(p => p.estat === 'actiu')?.length || 0,
            reptes_pendents: challenges?.filter(c => ['proposat', 'acceptat'].includes(c.estat))?.length || 0,
            events_actius: events?.filter(e => e.actiu)?.length || 0
        };
    } catch (error) {
        console.error('Error getting quick stats:', error.message);
        return null;
    }
}

// Executar exemples si es crida directament
if (require.main === module) {
    async function main() {
        console.log('🎯 EXEMPLES D\'ÚS DEL CLOUD DATABASE CONNECTOR\n');
        
        // Executar anàlisi complet
        await exempleCompletAnalisiDades();
        
        // Executar consultes específiques
        await exempleConsultesEspecifiques();
        
        // Mostrar estadístiques ràpides
        console.log('\n📊 Estadístiques ràpides:');
        const stats = await getQuickStats();
        if (stats) {
            console.log(JSON.stringify(stats, null, 2));
        }
    }
    
    main().catch(console.error);
}

// Exportar funcions per ús extern
module.exports = {
    CloudDatabaseConnector,
    exempleCompletAnalisiDades,
    exempleConsultesEspecifiques,
    getQuickStats
};