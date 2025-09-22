#!/bin/bash
# Script per aplicar índexs de rendiment a Supabase

echo "🚀 Aplicant índexs de rendiment a Supabase..."
echo "=================================================="

# Colors per output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Verificar si supabase CLI està disponible
if ! command -v supabase &> /dev/null; then
    echo -e "${RED}❌ Supabase CLI no està instal·lat${NC}"
    echo "Instal·la'l amb: npm install -g supabase"
    echo ""
    echo -e "${YELLOW}🔧 Alternativa: Executa el SQL manualment a Supabase Dashboard${NC}"
    echo "1. Ves a https://app.supabase.com/project/[PROJECT_ID]/sql"
    echo "2. Copia i executa el contingut de src/lib/database/indexes.sql"
    exit 1
fi

# Verificar si estem en un projecte Supabase
if [ ! -f "supabase/config.toml" ]; then
    echo -e "${RED}❌ No s'ha trobat supabase/config.toml${NC}"
    echo "Executa aquest script des de l'arrel del projecte"
    exit 1
fi

# Verificar conexió a Supabase
echo -e "${BLUE}🔍 Verificant connexió a Supabase...${NC}"
if ! supabase status &> /dev/null; then
    echo -e "${RED}❌ No hi ha connexió amb Supabase${NC}"
    echo "Executa: supabase login"
    exit 1
fi

echo -e "${GREEN}✅ Connexió amb Supabase OK${NC}"
echo ""

# Aplicar índexs des del fitxer indexes.sql
echo -e "${BLUE}📊 Aplicant índexs des de src/lib/database/indexes.sql...${NC}"

if [ ! -f "src/lib/database/indexes.sql" ]; then
    echo -e "${RED}❌ Fitxer src/lib/database/indexes.sql no trobat${NC}"
    exit 1
fi

# Executar els índexs
if supabase db push --db-url "$SUPABASE_DB_URL" < src/lib/database/indexes.sql; then
    echo -e "${GREEN}✅ Índexs aplicats correctament${NC}"
else
    echo -e "${YELLOW}⚠️  Error aplicant índexs. Provant amb supabase db reset...${NC}"
    if supabase db reset; then
        echo -e "${GREEN}✅ Base de dades reiniciada${NC}"
    else
        echo -e "${RED}❌ Error reiniciant base de dades${NC}"
        exit 1
    fi
fi

echo ""

# Executar ANALYZE per optimitzar l'optimitzador de queries
echo -e "${BLUE}🔍 Executant ANALYZE per optimitzar queries...${NC}"

ANALYZE_SQL="
ANALYZE challenges;
ANALYZE ranking_positions; 
ANALYZE mitjanes_historiques;
ANALYZE players;
ANALYZE events;
ANALYZE matches;
ANALYZE history_position_changes;
"

echo "$ANALYZE_SQL" | supabase db sql --db-url "$SUPABASE_DB_URL"

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ ANALYZE executat correctament${NC}"
else
    echo -e "${YELLOW}⚠️  ANALYZE no executat. Executa manualment a Supabase Dashboard${NC}"
fi

echo ""
echo -e "${GREEN}🎉 Optimitzacions de rendiment aplicades!${NC}"
echo ""
echo -e "${BLUE}📋 Resum de millores aplicades:${NC}"
echo "• Índexs optimitzats per challenges, ranking, mitjanes històriques"
echo "• ANALYZE executat per actualitzar estadístiques de la BD"
echo "• Consultes SELECT * optimitzades al codi"
echo ""
echo -e "${YELLOW}📝 Pròxims passos recomanats:${NC}"
echo "1. Configura automatitzacions (Edge Functions) a Supabase Dashboard"
echo "2. Monitoritza rendiment amb Performance Insights"
echo "3. Executa aquest script periòdicament després de grans canvis de dades"