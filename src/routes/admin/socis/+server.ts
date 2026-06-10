import { json } from '@sveltejs/kit';
import type { RequestHandler } from './$types';
import { requireAdmin } from '$lib/server/adminGuard';
import { supabaseAdmin } from '$lib/supabaseServiceClient';

function normalizeEmail(email: string | null | undefined): string | null {
  const cleaned = email?.trim().toLowerCase() ?? '';
  return cleaned.length > 0 ? cleaned : null;
}

function toNullableString(value: unknown): string | null {
  const cleaned = String(value ?? '').trim();
  return cleaned.length > 0 ? cleaned : null;
}

function parseSociPayload(body: any) {
  const numeroSoci = Number.parseInt(String(body?.numero_soci ?? ''), 10);
  const nom = String(body?.nom ?? '').trim();
  const cognoms = String(body?.cognoms ?? '').trim();
  const emailSoci = normalizeEmail(body?.email ?? null);
  const telefon = toNullableString(body?.telefon);
  const dataNaixement = toNullableString(body?.data_naixement);
  const deBaixa = Boolean(body?.de_baixa ?? false);

  return {
    numeroSoci,
    nom,
    cognoms,
    emailSoci,
    telefon,
    dataNaixement,
    deBaixa
  };
}

export const POST: RequestHandler = async (event) => {
  try {
    const guard = await requireAdmin(event);
    if (guard) return guard;

    const body = await event.request.json();
    const { numeroSoci, nom, cognoms, emailSoci, telefon, dataNaixement } = parseSociPayload(body);

    if (!Number.isInteger(numeroSoci) || numeroSoci <= 0 || !nom || !cognoms) {
      return json(
        { error: 'Els camps Numero Soci, Nom i Cognoms son obligatoris i valids' },
        { status: 400 }
      );
    }

    const { data: existingSoci, error: existingError } = await supabaseAdmin
      .from('socis')
      .select('numero_soci')
      .eq('numero_soci', numeroSoci)
      .maybeSingle();

    if (existingError) {
      return json({ error: existingError.message }, { status: 500 });
    }

    if (existingSoci) {
      return json({ error: 'Ja existeix un soci amb aquest numero' }, { status: 409 });
    }

    const { data: inserted, error: insertError } = await supabaseAdmin
      .from('socis')
      .insert([
        {
          numero_soci: numeroSoci,
          nom,
          cognoms,
          email: emailSoci,
          telefon,
          data_naixement: dataNaixement,
          de_baixa: false
        }
      ])
      .select('numero_soci')
      .single();

    if (insertError) {
      return json({ error: insertError.message }, { status: 500 });
    }

    return json({ ok: true, numero_soci: inserted.numero_soci });
  } catch (error: any) {
    return json({ error: error?.message || 'Error intern' }, { status: 500 });
  }
};

export const PUT: RequestHandler = async (event) => {
  try {
    const guard = await requireAdmin(event);
    if (guard) return guard;

    const body = await event.request.json();
    const numeroSociOriginal = Number.parseInt(String(body?.numero_soci_original ?? ''), 10);
    const { numeroSoci, nom, cognoms, emailSoci, telefon, dataNaixement, deBaixa } = parseSociPayload(body);

    if (
      !Number.isInteger(numeroSociOriginal) ||
      numeroSociOriginal <= 0 ||
      !Number.isInteger(numeroSoci) ||
      numeroSoci <= 0 ||
      !nom ||
      !cognoms
    ) {
      return json(
        { error: 'Els camps Numero Soci, Nom i Cognoms son obligatoris i valids' },
        { status: 400 }
      );
    }

    const { data: originalSoci, error: originalError } = await supabaseAdmin
      .from('socis')
      .select('numero_soci')
      .eq('numero_soci', numeroSociOriginal)
      .maybeSingle();

    if (originalError) {
      return json({ error: originalError.message }, { status: 500 });
    }

    if (!originalSoci) {
      return json({ error: 'No existeix el soci original' }, { status: 404 });
    }

    const sameNumber = numeroSociOriginal === numeroSoci;

    if (sameNumber) {
      const { error: updateError } = await supabaseAdmin
        .from('socis')
        .update({
          nom,
          cognoms,
          email: emailSoci,
          telefon,
          data_naixement: dataNaixement,
          de_baixa: deBaixa
        })
        .eq('numero_soci', numeroSociOriginal);

      if (updateError) {
        return json({ error: updateError.message }, { status: 500 });
      }

      return json({ ok: true, numero_soci: numeroSoci, renumbered: false });
    }

    // Renumeració atòmica via funció PostgreSQL (tota l'operació en una sola transacció)
    const { error: rpcError } = await supabaseAdmin.rpc('renumber_soci', {
      old_numero: numeroSociOriginal,
      new_numero: numeroSoci
    });

    if (rpcError) {
      const msg = rpcError.message ?? '';
      if (msg.includes('ja existeix') || msg.includes('duplicate') || rpcError.code === '23505') {
        return json({ error: 'Ja existeix un soci amb aquest numero' }, { status: 409 });
      }
      return json({ error: msg || 'No s\'ha pogut renumerar el soci' }, { status: 500 });
    }

    // Actualitzar les dades del soci (nom, cognoms, etc.) al nou número
    const { error: updateError } = await supabaseAdmin
      .from('socis')
      .update({
        nom,
        cognoms,
        email: emailSoci,
        telefon,
        data_naixement: dataNaixement,
        de_baixa: deBaixa
      })
      .eq('numero_soci', numeroSoci);

    if (updateError) {
      return json({ error: updateError.message }, { status: 500 });
    }

    return json({ ok: true, numero_soci: numeroSoci, renumbered: true });
  } catch (error: any) {
    return json({ error: error?.message || 'Error intern' }, { status: 500 });
  }
};

export const PATCH: RequestHandler = async (event) => {
  try {
    const guard = await requireAdmin(event);
    if (guard) return guard;

    const body = await event.request.json();
    const toAdd = Array.isArray(body?.toAdd) ? body.toAdd : [];
    const toUpdate = Array.isArray(body?.toUpdate) ? body.toUpdate : [];
    const toDeactivate = Array.isArray(body?.toDeactivate) ? body.toDeactivate : [];

    let added = 0;
    let updated = 0;
    let deactivated = 0;

    if (toAdd.length > 0) {
      const rowsToInsert = toAdd.map((s: any) => {
        const numeroSoci = Number.parseInt(String(s?.numero_soci ?? ''), 10);
        const nom = String(s?.nom ?? '').trim();
        const cognoms = String(s?.cognoms ?? '').trim();

        if (!Number.isInteger(numeroSoci) || numeroSoci <= 0 || !nom || !cognoms) {
          throw new Error('Hi ha dades de nous socis invàlides al CSV');
        }

        return {
          numero_soci: numeroSoci,
          nom,
          cognoms,
          email: normalizeEmail(s?.email ?? null),
          telefon: toNullableString(s?.telefon),
          data_naixement: toNullableString(s?.data_naixement),
          de_baixa: false
        };
      });

      const { data: insertedRows, error: insertError } = await supabaseAdmin
        .from('socis')
        .insert(rowsToInsert)
        .select('numero_soci');

      if (insertError) {
        return json({ error: insertError.message }, { status: 500 });
      }

      added = insertedRows?.length ?? rowsToInsert.length;
    }

    if (toUpdate.length > 0) {
      for (const s of toUpdate) {
        const numeroSoci = Number.parseInt(String(s?.numero_soci ?? ''), 10);
        if (!Number.isInteger(numeroSoci) || numeroSoci <= 0) {
          throw new Error('Hi ha dades de socis a actualitzar invàlides al CSV');
        }

        const { data: updatedRows, error: updateError } = await supabaseAdmin
          .from('socis')
          .update({
            email: normalizeEmail(s?.email ?? null),
            telefon: toNullableString(s?.telefon),
            data_naixement: toNullableString(s?.data_naixement)
          })
          .eq('numero_soci', numeroSoci)
          .select('numero_soci');

        if (updateError) {
          return json({ error: updateError.message }, { status: 500 });
        }

        updated += updatedRows?.length ?? 0;
      }
    }

    if (toDeactivate.length > 0) {
      const numerosToDeactivate = Array.from(
        new Set(
          toDeactivate
            .map((s: any) => Number.parseInt(String(s?.numero_soci ?? ''), 10))
            .filter((n: number) => Number.isInteger(n) && n > 0)
        )
      );

      if (numerosToDeactivate.length > 0) {
        const { data: deactivatedRows, error: deactivateError } = await supabaseAdmin
          .from('socis')
          .update({ de_baixa: true })
          .in('numero_soci', numerosToDeactivate)
          .select('numero_soci');

        if (deactivateError) {
          return json({ error: deactivateError.message }, { status: 500 });
        }

        deactivated = deactivatedRows?.length ?? 0;
      }
    }

    return json({ ok: true, added, updated, deactivated });
  } catch (error: any) {
    return json({ error: error?.message || 'Error intern' }, { status: 500 });
  }
};
