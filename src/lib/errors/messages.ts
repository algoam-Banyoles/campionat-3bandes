/**
 * Diccionari de missatges d'error en català per als usuaris finals
 * Organitzat per categories i amb contextualització
 */

import type { ErrorCode } from './types';

export interface ErrorMessage {
	userMessage: string;
	suggestion?: string;
	action?: string;
}

export const ERROR_MESSAGES: Record<ErrorCode, ErrorMessage> = {
	// Validació
	VALIDATION_REQUIRED_FIELD: {
		userMessage: 'Aquest camp és obligatori',
		suggestion: 'Si us plau, emplena tots els camps obligatoris',
		action: 'Corregir'
	},
	
	VALIDATION_INVALID_FORMAT: {
		userMessage: 'El format introduït no és vàlid',
		suggestion: 'Comprova que el format sigui correcte',
		action: 'Corregir'
	},
	
	VALIDATION_INVALID_RANGE: {
		userMessage: 'El valor està fora del rang permès',
		suggestion: 'Introdueix un valor dins del rang vàlid',
		action: 'Corregir'
	},

	// Base de dades
	DATABASE_CONNECTION_ERROR: {
		userMessage: 'No s\'ha pogut connectar amb la base de dades',
		suggestion: 'Comprova la teva connexió a internet i torna-ho a intentar',
		action: 'Tornar a intentar'
	},
	
	DATABASE_QUERY_ERROR: {
		userMessage: 'Error en consultar la informació',
		suggestion: 'Torna-ho a intentar dins d\'uns segons',
		action: 'Tornar a intentar'
	},
	
	DATABASE_CONSTRAINT_ERROR: {
		userMessage: 'Les dades introduïdes no compleixen les regles',
		suggestion: 'Revisa la informació i assegura\'t que sigui correcta',
		action: 'Revisar'
	},

	// Autenticació
	AUTH_INVALID_CREDENTIALS: {
		userMessage: 'Email o contrasenya incorrectes',
		suggestion: 'Verifica les teves credencials i torna-ho a intentar',
		action: 'Tornar a intentar'
	},
	
	AUTH_SESSION_EXPIRED: {
		userMessage: 'La teva sessió ha caducat',
		suggestion: 'Si us plau, inicia sessió de nou',
		action: 'Iniciar sessió'
	},
	
	AUTH_INSUFFICIENT_PERMISSIONS: {
		userMessage: 'No tens permisos per fer aquesta acció',
		suggestion: 'Contacta amb un administrador si creus que és un error',
		action: 'Contactar admin'
	},

	// Xarxa
	NETWORK_CONNECTION_ERROR: {
		userMessage: 'No s\'ha pogut conectar amb el servidor',
		suggestion: 'Comprova la teva connexió a internet',
		action: 'Tornar a intentar'
	},
	
	NETWORK_TIMEOUT: {
		userMessage: 'La sol·licitud ha trigat massa temps',
		suggestion: 'La connexió és lenta. Torna-ho a intentar',
		action: 'Tornar a intentar'
	},
	
	NETWORK_SERVER_ERROR: {
		userMessage: 'Error del servidor',
		suggestion: 'Estem resolent el problema. Torna-ho a intentar més tard',
		action: 'Tornar a intentar'
	},

	// Reptes
	CHALLENGE_INVALID_PLAYER: {
		userMessage: 'El jugador seleccionat no és vàlid',
		suggestion: 'Selecciona un jugador actiu del rànquing',
		action: 'Seleccionar altre'
	},
	
	CHALLENGE_POSITION_INVALID: {
		userMessage: 'No pots reptar aquest jugador',
		suggestion: 'Només pots reptar jugadors fins a 2 posicions per sobre',
		action: 'Seleccionar altre'
	},
	
	CHALLENGE_ALREADY_EXISTS: {
		userMessage: 'Ja tens un repte actiu amb aquest jugador',
		suggestion: 'Espera a resoldre el repte actual abans de crear-ne un altre',
		action: 'Veure reptes actius'
	},
	
	CHALLENGE_COOLDOWN_ACTIVE: {
		userMessage: 'Has d\'esperar abans de fer un altre repte',
		suggestion: 'Pots fer un nou repte cada 3 dies',
		action: 'Entesos'
	},

	// Rànquing
	RANKING_NOT_FOUND: {
		userMessage: 'No s\'ha trobat el rànquing',
		suggestion: 'Pot ser que el rànquing encara no estigui creat',
		action: 'Actualitzar'
	},
	
	RANKING_INVALID_POSITION: {
		userMessage: 'Posició del rànquing no vàlida',
		suggestion: 'Hi ha hagut un error en calcular la posició',
		action: 'Reportar error'
	},
	
	RANKING_UPDATE_ERROR: {
		userMessage: 'No s\'ha pogut actualitzar el rànquing',
		suggestion: 'Torna-ho a intentar dins d\'uns segons',
		action: 'Tornar a intentar'
	},

	// Socis
	MEMBER_NOT_FOUND: {
		userMessage: 'No s\'ha trobat el soci',
		suggestion: 'Verifica que el número de soci sigui correcte',
		action: 'Verificar'
	},
	
	MEMBER_NOT_ACTIVE: {
		userMessage: 'Aquest soci no està actiu',
		suggestion: 'Només els socis actius poden participar al campionat',
		action: 'Entesos'
	},
	
	MEMBER_DUPLICATE: {
		userMessage: 'Aquest soci ja existeix',
		suggestion: 'No es pot duplicar la informació d\'un soci',
		action: 'Verificar'
	},

	// General
	UNKNOWN_ERROR: {
		userMessage: 'S\'ha produït un error inesperat',
		suggestion: 'Si us plau, torna-ho a intentar o contacta amb suport',
		action: 'Tornar a intentar'
	},
	
	PERMISSION_DENIED: {
		userMessage: 'No tens permisos per aquesta acció',
		suggestion: 'Contacta amb un administrador si necessites accés',
		action: 'Contactar admin'
	},
	
	RESOURCE_NOT_FOUND: {
		userMessage: 'No s\'ha trobat el que buscaves',
		suggestion: 'Pot ser que hagi estat eliminat o no existeixi',
		action: 'Tornar enrere'
	}
};

/**
 * Missatges contextualitzats per diferents pàgines/components
 */
export const CONTEXTUAL_MESSAGES: Record<string, Partial<Record<ErrorCode, ErrorMessage>>> = {
	// Pàgina de rànquing
	ranking: {
		DATABASE_CONNECTION_ERROR: {
			userMessage: 'No s\'ha pogut carregar el rànquing',
			suggestion: 'Comprova la connexió i actualitza la pàgina',
			action: 'Actualitzar'
		},
		RANKING_NOT_FOUND: {
			userMessage: 'El rànquing encara no està disponible',
			suggestion: 'Els administradors han de crear el rànquing inicial',
			action: 'Entesos'
		}
	},

	// Pàgina de reptes
	challenges: {
		AUTH_SESSION_EXPIRED: {
			userMessage: 'Has de iniciar sessió per crear reptes',
			suggestion: 'Inicia sessió per continuar',
			action: 'Iniciar sessió'
		},
		CHALLENGE_COOLDOWN_ACTIVE: {
			userMessage: 'Encara no pots fer un altre repte',
			suggestion: 'Espera 3 dies des del teu últim repte jugat',
			action: 'Veure historial'
		}
	},

	// Formularis
	forms: {
		VALIDATION_REQUIRED_FIELD: {
			userMessage: 'Falten camps per emplenar',
			suggestion: 'Completa tots els camps marcats amb asterisk (*)',
			action: 'Revisar formulari'
		}
	},

	// Procés de login
	auth: {
		AUTH_INVALID_CREDENTIALS: {
			userMessage: 'Credencials incorrectes',
			suggestion: 'Verifica el teu email i contrasenya',
			action: 'Tornar a intentar'
		}
	}
};

/**
 * Obté el missatge d'error adequat segons el context
 */
export function getErrorMessage(
	code: ErrorCode, 
	context?: string
): ErrorMessage {
	// Primer busca missatge contextualitzat
	if (context && CONTEXTUAL_MESSAGES[context]?.[code]) {
		return CONTEXTUAL_MESSAGES[context][code]!;
	}
	
	// Fallback al missatge general
	return ERROR_MESSAGES[code] || ERROR_MESSAGES.UNKNOWN_ERROR;
}

/**
 * Missatges de success per accions completades
 */
export const SUCCESS_MESSAGES = {
	CHALLENGE_CREATED: 'Repte creat correctament',
	CHALLENGE_ACCEPTED: 'Repte acceptat. Programa la partida!',
	CHALLENGE_RESOLVED: 'Resultat registrat correctament',
	RANKING_UPDATED: 'Rànquing actualitzat',
	PROFILE_UPDATED: 'Perfil actualitzat correctament',
	PASSWORD_CHANGED: 'Contrasenya canviada correctament'
} as const;