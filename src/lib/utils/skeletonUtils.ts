import type { LoadingItem, LoadingPriority } from './loadingStates';

// Tipus per la configuració dels skeletons
export interface SkeletonConfig {
  theme: 'billiard' | 'default';
  shimmerSpeed: 'slow' | 'normal' | 'fast';
  urgency: 'safe' | 'warning' | 'critical' | 'none';
  offline: boolean;
  compact: boolean;
}

// Configuració per defecte dels skeletons
export const defaultSkeletonConfig: SkeletonConfig = {
  theme: 'billiard',
  shimmerSpeed: 'normal',
  urgency: 'none',
  offline: false,
  compact: false
};

// Mapper de prioritat a urgència per skeletons
export function mapPriorityToUrgency(priority: LoadingPriority): 'safe' | 'warning' | 'critical' | 'none' {
  switch (priority) {
    case 'low': return 'safe';
    case 'normal': return 'none';
    case 'high': return 'warning';
    case 'critical': return 'critical';
    default: return 'none';
  }
}

// Mapper de temps d'operació a velocitat de shimmer
export function mapElapsedTimeToSpeed(elapsedTime: number): 'slow' | 'normal' | 'fast' {
  if (elapsedTime > 10000) return 'slow'; // Més de 10s = slow
  if (elapsedTime > 5000) return 'normal'; // Entre 5-10s = normal
  return 'fast'; // Menys de 5s = fast
}

// Generar configuració de skeleton basada en l'estat de loading
export function generateSkeletonConfig(
  loadingItem?: LoadingItem,
  baseConfig: Partial<SkeletonConfig> = {}
): SkeletonConfig {
  const config = { ...defaultSkeletonConfig, ...baseConfig };
  
  if (loadingItem) {
    // Mapear prioritat a urgència
    config.urgency = mapPriorityToUrgency(loadingItem.priority);
    
    // Ajustar velocitat segons temps transcorregut
    const elapsedTime = (loadingItem.endTime || Date.now()) - loadingItem.startTime;
    config.shimmerSpeed = mapElapsedTimeToSpeed(elapsedTime);
    
    // Detectar estat offline (simplificat per ara)
    config.offline = false; // Podria ser més sofisticat
  }
  
  return config;
}

// Utilitats per generar variants de mides realistes
export interface ContentVariants {
  names: string[];
  widths: string[];
  heights: string[];
}

// Variants per noms de jugadors (basades en noms reals del billar)
export const playerNameVariants: ContentVariants = {
  names: [
    'Josep Maria Codina',
    'Francesc Viaplana', 
    'Antoni Castillo',
    'Ramon González',
    'Pere Comas',
    'Jordi Civil',
    'Eduard Royes',
    'Jaume Armengol',
    'Lluís González',
    'Domingo Corbalán'
  ],
  widths: ['75%', '85%', '90%', '80%', '70%', '95%', '82%', '88%', '77%', '92%'],
  heights: ['16px', '18px', '16px', '17px', '16px', '18px', '17px', '16px', '17px', '18px']
};

// Variants per posicions (1-20 segons les regles del campionat)
export const positionVariants: ContentVariants = {
  names: Array.from({ length: 20 }, (_, i) => `${i + 1}`),
  widths: Array.from({ length: 20 }, () => '24px'),
  heights: Array.from({ length: 20 }, () => '24px')
};

// Variants per puntuacions de partits
export const scoreVariants: ContentVariants = {
  names: ['25-15', '25-18', '25-20', '25-12', '25-22', '25-8', '25-25', '25-16', '25-14', '25-19'],
  widths: ['60px', '60px', '60px', '60px', '60px', '60px', '60px', '60px', '60px', '60px'],
  heights: ['24px', '24px', '24px', '24px', '24px', '24px', '24px', '24px', '24px', '24px']
};

// Generar variant aleatòria d'una llista
export function getRandomVariant(variants: ContentVariants, index?: number): {
  name: string;
  width: string;
  height: string;
} {
  const i = index !== undefined ? index % variants.names.length : Math.floor(Math.random() * variants.names.length);
  return {
    name: variants.names[i],
    width: variants.widths[i],
    height: variants.heights[i]
  };
}

// Generar patterns realistes per diferents continguts
export interface SkeletonPattern {
  count: number;
  variants: Array<{
    width: string;
    height?: string;
    variant?: 'rectangular' | 'circular' | 'text';
    urgency?: 'safe' | 'warning' | 'critical' | 'none';
  }>;
}

// Patterns per taula de rankings (exactament 20 jugadors)
export function generateRankingPattern(): SkeletonPattern {
  const patterns = [];
  
  for (let i = 0; i < 20; i++) {
    const playerVariant = getRandomVariant(playerNameVariants, i);
    let urgency: 'safe' | 'warning' | 'critical' | 'none' = 'none';
    
    // Assignar urgència segons posició
    if (i < 3) urgency = 'safe'; // Top 3
    else if (i >= 17) urgency = 'critical'; // Últimes 3 posicions
    else if (i >= 15) urgency = 'warning'; // Posicions de risc
    
    patterns.push({
      width: playerVariant.width,
      height: '48px',
      variant: 'rectangular' as const,
      urgency
    });
  }
  
  return {
    count: 20,
    variants: patterns
  };
}

// Patterns per llista d'espera (màxim 15 jugadors)
export function generateWaitingListPattern(maxPlayers: number = 10): SkeletonPattern {
  const patterns = [];
  
  for (let i = 0; i < Math.min(maxPlayers, 15); i++) {
    const playerVariant = getRandomVariant(playerNameVariants, i);
    let urgency: 'safe' | 'warning' | 'critical' | 'none' = 'none';
    
    // Assignar urgència segons posició a la llista d'espera
    if (i < 3) urgency = 'safe'; // Primers 3: accés immediat
    else if (i < 7) urgency = 'warning'; // Següents 4: següent ronda
    else urgency = 'critical'; // Resta: accés difícil
    
    patterns.push({
      width: playerVariant.width,
      height: '44px',
      variant: 'rectangular' as const,
      urgency
    });
  }
  
  return {
    count: Math.min(maxPlayers, 15),
    variants: patterns
  };
}

// Patterns per desafiaments amb urgència temporal
export function generateChallengePattern(daysRemaining: number): SkeletonPattern {
  let urgency: 'safe' | 'warning' | 'critical' | 'none' = 'none';
  
  // Determinar urgència segons dies restants
  if (daysRemaining <= 1) urgency = 'critical';
  else if (daysRemaining <= 3) urgency = 'warning';
  else if (daysRemaining <= 7) urgency = 'safe';
  
  return {
    count: 1,
    variants: [{
      width: '100%',
      height: '120px',
      variant: 'rectangular' as const,
      urgency
    }]
  };
}

// Utilitats per animacions de transició
export interface TransitionConfig {
  duration: number;
  easing: string;
  stagger?: number;
}

export const transitionConfigs = {
  // Transició ràpida per elements simples
  fast: {
    duration: 200,
    easing: 'ease-out'
  },
  // Transició normal per contingut general
  normal: {
    duration: 300,
    easing: 'ease-in-out'
  },
  // Transició lenta per canvis importants
  slow: {
    duration: 500,
    easing: 'ease-in-out'
  },
  // Transició amb stagger per llistes
  staggered: {
    duration: 300,
    easing: 'ease-out',
    stagger: 50 // 50ms entre elements
  }
};

// Helper per aplicar staggered animations
export function getStaggeredDelay(index: number, stagger: number = 50): string {
  return `${index * stagger}ms`;
}

// Utilitats per responsive behavior
export interface ResponsiveConfig {
  mobile: Partial<SkeletonConfig>;
  tablet: Partial<SkeletonConfig>;
  desktop: Partial<SkeletonConfig>;
}

export const responsiveConfigs: ResponsiveConfig = {
  mobile: {
    compact: true,
    shimmerSpeed: 'fast'
  },
  tablet: {
    compact: false,
    shimmerSpeed: 'normal'
  },
  desktop: {
    compact: false,
    shimmerSpeed: 'normal'
  }
};

// Helper per obtenir configuració responsive
export function getResponsiveConfig(screenWidth: number): Partial<SkeletonConfig> {
  if (screenWidth < 768) return responsiveConfigs.mobile;
  if (screenWidth < 1024) return responsiveConfigs.tablet;
  return responsiveConfigs.desktop;
}

// Validation helpers per championship rules
export function validateRankingCount(count: number): boolean {
  return count <= 20; // Màxim 20 jugadors segons regles
}

export function validateWaitingListCount(count: number): boolean {
  return count <= 15; // Màxim realista per llista d'espera
}

export function validateChallengeDeadline(days: number): boolean {
  return days >= 0 && days <= 7; // Entre 0 i 7 dies per acceptar
}

export function validateMatchDeadline(days: number): boolean {
  return days >= 0 && days <= 15; // Entre 0 i 15 dies per disputar
}