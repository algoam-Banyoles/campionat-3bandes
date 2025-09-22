#!/bin/bash
# Script per configurar automatitzacions a Supabase

echo "⚡ Configurant automatitzacions per al campionat..."
echo "================================================"

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Verificar Supabase CLI
if ! command -v supabase &> /dev/null; then
    echo -e "${RED}❌ Supabase CLI no trobat${NC}"
    echo "Instal·la amb: npm install -g supabase"
    exit 1
fi

echo -e "${BLUE}📦 Desplegant Edge Functions...${NC}"

# Desplegar function de penalitzacions
if [ -f "supabase/functions/aplica-penalitzacions.ts" ]; then
    echo "Desplegant aplica-penalitzacions..."
    if supabase functions deploy aplica-penalitzacions; then
        echo -e "${GREEN}✅ aplica-penalitzacions desplegada${NC}"
    else
        echo -e "${RED}❌ Error desplegant aplica-penalitzacions${NC}"
    fi
else
    echo -e "${YELLOW}⚠️  supabase/functions/aplica-penalitzacions.ts no trobat${NC}"
fi

# Crear function per pre-inactivitat si no existeix
if [ ! -f "supabase/functions/aplica-pre-inactivitat.ts" ]; then
    echo -e "${BLUE}📝 Creant function aplica-pre-inactivitat...${NC}"
    
    mkdir -p supabase/functions/aplica-pre-inactivitat
    
    cat > supabase/functions/aplica-pre-inactivitat/index.ts << 'EOF'
import { serve } from 'std/server';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;

serve(async (req) => {
  try {
    const supabase = createClient(supabaseUrl, supabaseServiceKey);
    
    // Obtenir event actiu
    const { data: events } = await supabase
      .from('events')
      .select('id')
      .eq('actiu', true)
      .limit(1);
      
    if (!events || events.length === 0) {
      return new Response('No hi ha events actius', { status: 400 });
    }
    
    const eventId = events[0].id;
    
    // Aplicar pre-inactivitat
    const { error } = await supabase.rpc('apply_pre_inactivity', {
      p_event: eventId
    });
    
    if (error) {
      console.error('Error aplicant pre-inactivitat:', error);
      return new Response(`Error: ${error.message}`, { status: 500 });
    }
    
    return new Response('Pre-inactivitat aplicada correctament', { status: 200 });
    
  } catch (error) {
    console.error('Error intern:', error);
    return new Response(`Error intern: ${error.message}`, { status: 500 });
  }
});
EOF
    
    echo -e "${GREEN}✅ Function aplica-pre-inactivitat creada${NC}"
fi

# Desplegar pre-inactivitat
echo "Desplegant aplica-pre-inactivitat..."
if supabase functions deploy aplica-pre-inactivitat; then
    echo -e "${GREEN}✅ aplica-pre-inactivitat desplegada${NC}"
else
    echo -e "${RED}❌ Error desplegant aplica-pre-inactivitat${NC}"
fi

echo ""
echo -e "${GREEN}🎉 Edge Functions desplegades!${NC}"
echo ""
echo -e "${YELLOW}📝 Pròxims passos manuals (Supabase Dashboard):${NC}"
echo ""
echo "1. Configurar Scheduled Functions:"
echo "   • Ves a Dashboard > Functions > [function-name] > Settings"
echo "   • Afegeix trigger 'Scheduled (cron)'"
echo ""
echo "2. Configuració recomanada:"
echo "   • aplica-penalitzacions: '0 2 * * *' (cada dia a les 2:00)"
echo "   • aplica-pre-inactivitat: '0 3 * * 0' (cada diumenge a les 3:00)"
echo ""
echo "3. Variables d'entorn necessàries:"
echo "   • SUPABASE_URL (ja configurat)"
echo "   • SUPABASE_SERVICE_ROLE_KEY (ja configurat)"
echo "   • API_KEY (opcional per aplica-penalitzacions)"
echo ""
echo -e "${BLUE}🔗 URL Dashboard:${NC}"
echo "https://app.supabase.com/project/[PROJECT_ID]/functions"