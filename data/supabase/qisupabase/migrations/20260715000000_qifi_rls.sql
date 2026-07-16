-- QiFi Finance Table Workspace Security Migration
-- 1. Create workspace_members table if not exists
CREATE TABLE IF NOT EXISTS public.workspace_members (
  workspace_id text NOT NULL,
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  role text NOT NULL DEFAULT 'member',
  created_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (workspace_id, user_id)
);

-- 2. Enable RLS on workspace_members
ALTER TABLE public.workspace_members ENABLE ROW LEVEL SECURITY;

-- 3. Allow an authenticated user to read only their own membership rows
DROP POLICY IF EXISTS select_own_membership ON public.workspace_members;
CREATE POLICY select_own_membership ON public.workspace_members
  FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id);

-- 4. Assign single existing auth user to default workspace if applicable
DO $$
DECLARE
  user_count integer;
  single_user_id uuid;
  membership_exists boolean;
BEGIN
  SELECT count(*) INTO user_count FROM auth.users;
  
  IF user_count = 1 THEN
    SELECT id INTO single_user_id FROM auth.users LIMIT 1;
    SELECT exists(
      SELECT 1 FROM public.workspace_members 
      WHERE workspace_id = 'default' AND user_id = single_user_id
    ) INTO membership_exists;
    
    IF NOT membership_exists THEN
      INSERT INTO public.workspace_members (workspace_id, user_id, role)
      VALUES ('default', single_user_id, 'owner');
    END IF;
  END IF;
END $$;

-- Helper macro to enable RLS and create workspace-based policies
-- QiFi Tables to migrate:
-- 1. financial_accounts
-- 2. ledger_accounts
-- 3. categories
-- 4. transactions
-- 5. journal_entries
-- 6. journal_lines
-- 7. import_batches
-- 8. import_rows_raw
-- 9. classification_rules
-- 10. attachments
-- 11. statements
-- 12. recurring_transactions
-- 13. counterparties
-- 14. obligations

-- Enable RLS on all QiFi Tables
ALTER TABLE public.financial_accounts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ledger_accounts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.journal_entries ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.journal_lines ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.import_batches ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.import_rows_raw ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.classification_rules ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.attachments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.statements ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.recurring_transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.counterparties ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.obligations ENABLE ROW LEVEL SECURITY;

-- Policies for financial_accounts
DROP POLICY IF EXISTS member_select_financial_accounts ON public.financial_accounts;
CREATE POLICY member_select_financial_accounts ON public.financial_accounts FOR SELECT TO authenticated USING (
  workspace_id IN (SELECT workspace_id FROM public.workspace_members WHERE user_id = auth.uid())
);
DROP POLICY IF EXISTS member_insert_financial_accounts ON public.financial_accounts;
CREATE POLICY member_insert_financial_accounts ON public.financial_accounts FOR INSERT TO authenticated WITH CHECK (
  workspace_id IN (SELECT workspace_id FROM public.workspace_members WHERE user_id = auth.uid())
);
DROP POLICY IF EXISTS member_update_financial_accounts ON public.financial_accounts;
CREATE POLICY member_update_financial_accounts ON public.financial_accounts FOR UPDATE TO authenticated USING (
  workspace_id IN (SELECT workspace_id FROM public.workspace_members WHERE user_id = auth.uid())
) WITH CHECK (
  workspace_id IN (SELECT workspace_id FROM public.workspace_members WHERE user_id = auth.uid())
);
DROP POLICY IF EXISTS member_delete_financial_accounts ON public.financial_accounts;
CREATE POLICY member_delete_financial_accounts ON public.financial_accounts FOR DELETE TO authenticated USING (
  workspace_id IN (SELECT workspace_id FROM public.workspace_members WHERE user_id = auth.uid())
);

-- Policies for ledger_accounts
DROP POLICY IF EXISTS member_select_ledger_accounts ON public.ledger_accounts;
CREATE POLICY member_select_ledger_accounts ON public.ledger_accounts FOR SELECT TO authenticated USING (
  workspace_id IN (SELECT workspace_id FROM public.workspace_members WHERE user_id = auth.uid())
);
DROP POLICY IF EXISTS member_insert_ledger_accounts ON public.ledger_accounts;
CREATE POLICY member_insert_ledger_accounts ON public.ledger_accounts FOR INSERT TO authenticated WITH CHECK (
  workspace_id IN (SELECT workspace_id FROM public.workspace_members WHERE user_id = auth.uid())
);
DROP POLICY IF EXISTS member_update_ledger_accounts ON public.ledger_accounts;
CREATE POLICY member_update_ledger_accounts ON public.ledger_accounts FOR UPDATE TO authenticated USING (
  workspace_id IN (SELECT workspace_id FROM public.workspace_members WHERE user_id = auth.uid())
) WITH CHECK (
  workspace_id IN (SELECT workspace_id FROM public.workspace_members WHERE user_id = auth.uid())
);
DROP POLICY IF EXISTS member_delete_ledger_accounts ON public.ledger_accounts;
CREATE POLICY member_delete_ledger_accounts ON public.ledger_accounts FOR DELETE TO authenticated USING (
  workspace_id IN (SELECT workspace_id FROM public.workspace_members WHERE user_id = auth.uid())
);

-- Policies for categories
DROP POLICY IF EXISTS member_select_categories ON public.categories;
CREATE POLICY member_select_categories ON public.categories FOR SELECT TO authenticated USING (
  workspace_id IN (SELECT workspace_id FROM public.workspace_members WHERE user_id = auth.uid())
);
DROP POLICY IF EXISTS member_insert_categories ON public.categories;
CREATE POLICY member_insert_categories ON public.categories FOR INSERT TO authenticated WITH CHECK (
  workspace_id IN (SELECT workspace_id FROM public.workspace_members WHERE user_id = auth.uid())
);
DROP POLICY IF EXISTS member_update_categories ON public.categories;
CREATE POLICY member_update_categories ON public.categories FOR UPDATE TO authenticated USING (
  workspace_id IN (SELECT workspace_id FROM public.workspace_members WHERE user_id = auth.uid())
) WITH CHECK (
  workspace_id IN (SELECT workspace_id FROM public.workspace_members WHERE user_id = auth.uid())
);
DROP POLICY IF EXISTS member_delete_categories ON public.categories;
CREATE POLICY member_delete_categories ON public.categories FOR DELETE TO authenticated USING (
  workspace_id IN (SELECT workspace_id FROM public.workspace_members WHERE user_id = auth.uid())
);

-- Policies for transactions
DROP POLICY IF EXISTS member_select_transactions ON public.transactions;
CREATE POLICY member_select_transactions ON public.transactions FOR SELECT TO authenticated USING (
  workspace_id IN (SELECT workspace_id FROM public.workspace_members WHERE user_id = auth.uid())
);
DROP POLICY IF EXISTS member_insert_transactions ON public.transactions;
CREATE POLICY member_insert_transactions ON public.transactions FOR INSERT TO authenticated WITH CHECK (
  workspace_id IN (SELECT workspace_id FROM public.workspace_members WHERE user_id = auth.uid())
);
DROP POLICY IF EXISTS member_update_transactions ON public.transactions;
CREATE POLICY member_update_transactions ON public.transactions FOR UPDATE TO authenticated USING (
  workspace_id IN (SELECT workspace_id FROM public.workspace_members WHERE user_id = auth.uid())
) WITH CHECK (
  workspace_id IN (SELECT workspace_id FROM public.workspace_members WHERE user_id = auth.uid())
);
DROP POLICY IF EXISTS member_delete_transactions ON public.transactions;
CREATE POLICY member_delete_transactions ON public.transactions FOR DELETE TO authenticated USING (
  workspace_id IN (SELECT workspace_id FROM public.workspace_members WHERE user_id = auth.uid())
);

-- Policies for journal_entries
DROP POLICY IF EXISTS member_select_journal_entries ON public.journal_entries;
CREATE POLICY member_select_journal_entries ON public.journal_entries FOR SELECT TO authenticated USING (
  workspace_id IN (SELECT workspace_id FROM public.workspace_members WHERE user_id = auth.uid())
);
DROP POLICY IF EXISTS member_insert_journal_entries ON public.journal_entries;
CREATE POLICY member_insert_journal_entries ON public.journal_entries FOR INSERT TO authenticated WITH CHECK (
  workspace_id IN (SELECT workspace_id FROM public.workspace_members WHERE user_id = auth.uid())
);
DROP POLICY IF EXISTS member_update_journal_entries ON public.journal_entries;
CREATE POLICY member_update_journal_entries ON public.journal_entries FOR UPDATE TO authenticated USING (
  workspace_id IN (SELECT workspace_id FROM public.workspace_members WHERE user_id = auth.uid())
) WITH CHECK (
  workspace_id IN (SELECT workspace_id FROM public.workspace_members WHERE user_id = auth.uid())
);
DROP POLICY IF EXISTS member_delete_journal_entries ON public.journal_entries;
CREATE POLICY member_delete_journal_entries ON public.journal_entries FOR DELETE TO authenticated USING (
  workspace_id IN (SELECT workspace_id FROM public.workspace_members WHERE user_id = auth.uid())
);

-- Policies for journal_lines
DROP POLICY IF EXISTS member_select_journal_lines ON public.journal_lines;
CREATE POLICY member_select_journal_lines ON public.journal_lines FOR SELECT TO authenticated USING (
  workspace_id IN (SELECT workspace_id FROM public.workspace_members WHERE user_id = auth.uid())
);
DROP POLICY IF EXISTS member_insert_journal_lines ON public.journal_lines;
CREATE POLICY member_insert_journal_lines ON public.journal_lines FOR INSERT TO authenticated WITH CHECK (
  workspace_id IN (SELECT workspace_id FROM public.workspace_members WHERE user_id = auth.uid())
);
DROP POLICY IF EXISTS member_update_journal_lines ON public.journal_lines;
CREATE POLICY member_update_journal_lines ON public.journal_lines FOR UPDATE TO authenticated USING (
  workspace_id IN (SELECT workspace_id FROM public.workspace_members WHERE user_id = auth.uid())
) WITH CHECK (
  workspace_id IN (SELECT workspace_id FROM public.workspace_members WHERE user_id = auth.uid())
);
DROP POLICY IF EXISTS member_delete_journal_lines ON public.journal_lines;
CREATE POLICY member_delete_journal_lines ON public.journal_lines FOR DELETE TO authenticated USING (
  workspace_id IN (SELECT workspace_id FROM public.workspace_members WHERE user_id = auth.uid())
);

-- Policies for import_batches
DROP POLICY IF EXISTS member_select_import_batches ON public.import_batches;
CREATE POLICY member_select_import_batches ON public.import_batches FOR SELECT TO authenticated USING (
  workspace_id IN (SELECT workspace_id FROM public.workspace_members WHERE user_id = auth.uid())
);
DROP POLICY IF EXISTS member_insert_import_batches ON public.import_batches;
CREATE POLICY member_insert_import_batches ON public.import_batches FOR INSERT TO authenticated WITH CHECK (
  workspace_id IN (SELECT workspace_id FROM public.workspace_members WHERE user_id = auth.uid())
);
DROP POLICY IF EXISTS member_update_import_batches ON public.import_batches;
CREATE POLICY member_update_import_batches ON public.import_batches FOR UPDATE TO authenticated USING (
  workspace_id IN (SELECT workspace_id FROM public.workspace_members WHERE user_id = auth.uid())
) WITH CHECK (
  workspace_id IN (SELECT workspace_id FROM public.workspace_members WHERE user_id = auth.uid())
);
DROP POLICY IF EXISTS member_delete_import_batches ON public.import_batches;
CREATE POLICY member_delete_import_batches ON public.import_batches FOR DELETE TO authenticated USING (
  workspace_id IN (SELECT workspace_id FROM public.workspace_members WHERE user_id = auth.uid())
);

-- Policies for import_rows_raw
DROP POLICY IF EXISTS member_select_import_rows_raw ON public.import_rows_raw;
CREATE POLICY member_select_import_rows_raw ON public.import_rows_raw FOR SELECT TO authenticated USING (
  workspace_id IN (SELECT workspace_id FROM public.workspace_members WHERE user_id = auth.uid())
);
DROP POLICY IF EXISTS member_insert_import_rows_raw ON public.import_rows_raw;
CREATE POLICY member_insert_import_rows_raw ON public.import_rows_raw FOR INSERT TO authenticated WITH CHECK (
  workspace_id IN (SELECT workspace_id FROM public.workspace_members WHERE user_id = auth.uid())
);
DROP POLICY IF EXISTS member_update_import_rows_raw ON public.import_rows_raw;
CREATE POLICY member_update_import_rows_raw ON public.import_rows_raw FOR UPDATE TO authenticated USING (
  workspace_id IN (SELECT workspace_id FROM public.workspace_members WHERE user_id = auth.uid())
) WITH CHECK (
  workspace_id IN (SELECT workspace_id FROM public.workspace_members WHERE user_id = auth.uid())
);
DROP POLICY IF EXISTS member_delete_import_rows_raw ON public.import_rows_raw;
CREATE POLICY member_delete_import_rows_raw ON public.import_rows_raw FOR DELETE TO authenticated USING (
  workspace_id IN (SELECT workspace_id FROM public.workspace_members WHERE user_id = auth.uid())
);

-- Policies for classification_rules
DROP POLICY IF EXISTS member_select_classification_rules ON public.classification_rules;
CREATE POLICY member_select_classification_rules ON public.classification_rules FOR SELECT TO authenticated USING (
  workspace_id IN (SELECT workspace_id FROM public.workspace_members WHERE user_id = auth.uid())
);
DROP POLICY IF EXISTS member_insert_classification_rules ON public.classification_rules;
CREATE POLICY member_insert_classification_rules ON public.classification_rules FOR INSERT TO authenticated WITH CHECK (
  workspace_id IN (SELECT workspace_id FROM public.workspace_members WHERE user_id = auth.uid())
);
DROP POLICY IF EXISTS member_update_classification_rules ON public.classification_rules;
CREATE POLICY member_update_classification_rules ON public.classification_rules FOR UPDATE TO authenticated USING (
  workspace_id IN (SELECT workspace_id FROM public.workspace_members WHERE user_id = auth.uid())
) WITH CHECK (
  workspace_id IN (SELECT workspace_id FROM public.workspace_members WHERE user_id = auth.uid())
);
DROP POLICY IF EXISTS member_delete_classification_rules ON public.classification_rules;
CREATE POLICY member_delete_classification_rules ON public.classification_rules FOR DELETE TO authenticated USING (
  workspace_id IN (SELECT workspace_id FROM public.workspace_members WHERE user_id = auth.uid())
);

-- Policies for attachments
DROP POLICY IF EXISTS member_select_attachments ON public.attachments;
CREATE POLICY member_select_attachments ON public.attachments FOR SELECT TO authenticated USING (
  workspace_id IN (SELECT workspace_id FROM public.workspace_members WHERE user_id = auth.uid())
);
DROP POLICY IF EXISTS member_insert_attachments ON public.attachments;
CREATE POLICY member_insert_attachments ON public.attachments FOR INSERT TO authenticated WITH CHECK (
  workspace_id IN (SELECT workspace_id FROM public.workspace_members WHERE user_id = auth.uid())
);
DROP POLICY IF EXISTS member_update_attachments ON public.attachments;
CREATE POLICY member_update_attachments ON public.attachments FOR UPDATE TO authenticated USING (
  workspace_id IN (SELECT workspace_id FROM public.workspace_members WHERE user_id = auth.uid())
) WITH CHECK (
  workspace_id IN (SELECT workspace_id FROM public.workspace_members WHERE user_id = auth.uid())
);
DROP POLICY IF EXISTS member_delete_attachments ON public.attachments;
CREATE POLICY member_delete_attachments ON public.attachments FOR DELETE TO authenticated USING (
  workspace_id IN (SELECT workspace_id FROM public.workspace_members WHERE user_id = auth.uid())
);

-- Policies for statements
DROP POLICY IF EXISTS member_select_statements ON public.statements;
CREATE POLICY member_select_statements ON public.statements FOR SELECT TO authenticated USING (
  workspace_id IN (SELECT workspace_id FROM public.workspace_members WHERE user_id = auth.uid())
);
DROP POLICY IF EXISTS member_insert_statements ON public.statements;
CREATE POLICY member_insert_statements ON public.statements FOR INSERT TO authenticated WITH CHECK (
  workspace_id IN (SELECT workspace_id FROM public.workspace_members WHERE user_id = auth.uid())
);
DROP POLICY IF EXISTS member_update_statements ON public.statements;
CREATE POLICY member_update_statements ON public.statements FOR UPDATE TO authenticated USING (
  workspace_id IN (SELECT workspace_id FROM public.workspace_members WHERE user_id = auth.uid())
) WITH CHECK (
  workspace_id IN (SELECT workspace_id FROM public.workspace_members WHERE user_id = auth.uid())
);
DROP POLICY IF EXISTS member_delete_statements ON public.statements;
CREATE POLICY member_delete_statements ON public.statements FOR DELETE TO authenticated USING (
  workspace_id IN (SELECT workspace_id FROM public.workspace_members WHERE user_id = auth.uid())
);

-- Policies for recurring_transactions
DROP POLICY IF EXISTS member_select_recurring_transactions ON public.recurring_transactions;
CREATE POLICY member_select_recurring_transactions ON public.recurring_transactions FOR SELECT TO authenticated USING (
  workspace_id IN (SELECT workspace_id FROM public.workspace_members WHERE user_id = auth.uid())
);
DROP POLICY IF EXISTS member_insert_recurring_transactions ON public.recurring_transactions;
CREATE POLICY member_insert_recurring_transactions ON public.recurring_transactions FOR INSERT TO authenticated WITH CHECK (
  workspace_id IN (SELECT workspace_id FROM public.workspace_members WHERE user_id = auth.uid())
);
DROP POLICY IF EXISTS member_update_recurring_transactions ON public.recurring_transactions;
CREATE POLICY member_update_recurring_transactions ON public.recurring_transactions FOR UPDATE TO authenticated USING (
  workspace_id IN (SELECT workspace_id FROM public.workspace_members WHERE user_id = auth.uid())
) WITH CHECK (
  workspace_id IN (SELECT workspace_id FROM public.workspace_members WHERE user_id = auth.uid())
);
DROP POLICY IF EXISTS member_delete_recurring_transactions ON public.recurring_transactions;
CREATE POLICY member_delete_recurring_transactions ON public.recurring_transactions FOR DELETE TO authenticated USING (
  workspace_id IN (SELECT workspace_id FROM public.workspace_members WHERE user_id = auth.uid())
);

-- Policies for counterparties
DROP POLICY IF EXISTS member_select_counterparties ON public.counterparties;
CREATE POLICY member_select_counterparties ON public.counterparties FOR SELECT TO authenticated USING (
  workspace_id IN (SELECT workspace_id FROM public.workspace_members WHERE user_id = auth.uid())
);
DROP POLICY IF EXISTS member_insert_counterparties ON public.counterparties;
CREATE POLICY member_insert_counterparties ON public.counterparties FOR INSERT TO authenticated WITH CHECK (
  workspace_id IN (SELECT workspace_id FROM public.workspace_members WHERE user_id = auth.uid())
);
DROP POLICY IF EXISTS member_update_counterparties ON public.counterparties;
CREATE POLICY member_update_counterparties ON public.counterparties FOR UPDATE TO authenticated USING (
  workspace_id IN (SELECT workspace_id FROM public.workspace_members WHERE user_id = auth.uid())
) WITH CHECK (
  workspace_id IN (SELECT workspace_id FROM public.workspace_members WHERE user_id = auth.uid())
);
DROP POLICY IF EXISTS member_delete_counterparties ON public.counterparties;
CREATE POLICY member_delete_counterparties ON public.counterparties FOR DELETE TO authenticated USING (
  workspace_id IN (SELECT workspace_id FROM public.workspace_members WHERE user_id = auth.uid())
);

-- Policies for obligations
DROP POLICY IF EXISTS member_select_obligations ON public.obligations;
CREATE POLICY member_select_obligations ON public.obligations FOR SELECT TO authenticated USING (
  workspace_id IN (SELECT workspace_id FROM public.workspace_members WHERE user_id = auth.uid())
);
DROP POLICY IF EXISTS member_insert_obligations ON public.obligations;
CREATE POLICY member_insert_obligations ON public.obligations FOR INSERT TO authenticated WITH CHECK (
  workspace_id IN (SELECT workspace_id FROM public.workspace_members WHERE user_id = auth.uid())
);
DROP POLICY IF EXISTS member_update_obligations ON public.obligations;
CREATE POLICY member_update_obligations ON public.obligations FOR UPDATE TO authenticated USING (
  workspace_id IN (SELECT workspace_id FROM public.workspace_members WHERE user_id = auth.uid())
) WITH CHECK (
  workspace_id IN (SELECT workspace_id FROM public.workspace_members WHERE user_id = auth.uid())
);
DROP POLICY IF EXISTS member_delete_obligations ON public.obligations;
CREATE POLICY member_delete_obligations ON public.obligations FOR DELETE TO authenticated USING (
  workspace_id IN (SELECT workspace_id FROM public.workspace_members WHERE user_id = auth.uid())
);

-- Storage policies for qifi-vault bucket restricting users to workspaces/<workspace_id>/
DROP POLICY IF EXISTS select_vault_objects ON storage.objects;
CREATE POLICY select_vault_objects ON storage.objects FOR SELECT TO authenticated USING (
  bucket_id = 'qifi-vault' AND
  split_part(name, '/', 1) = 'workspaces' AND
  split_part(name, '/', 2) IN (SELECT workspace_id FROM public.workspace_members WHERE user_id = auth.uid())
);

DROP POLICY IF EXISTS insert_vault_objects ON storage.objects;
CREATE POLICY insert_vault_objects ON storage.objects FOR INSERT TO authenticated WITH CHECK (
  bucket_id = 'qifi-vault' AND
  split_part(name, '/', 1) = 'workspaces' AND
  split_part(name, '/', 2) IN (SELECT workspace_id FROM public.workspace_members WHERE user_id = auth.uid())
);

DROP POLICY IF EXISTS update_vault_objects ON storage.objects;
CREATE POLICY update_vault_objects ON storage.objects FOR UPDATE TO authenticated USING (
  bucket_id = 'qifi-vault' AND
  split_part(name, '/', 1) = 'workspaces' AND
  split_part(name, '/', 2) IN (SELECT workspace_id FROM public.workspace_members WHERE user_id = auth.uid())
) WITH CHECK (
  bucket_id = 'qifi-vault' AND
  split_part(name, '/', 1) = 'workspaces' AND
  split_part(name, '/', 2) IN (SELECT workspace_id FROM public.workspace_members WHERE user_id = auth.uid())
);

DROP POLICY IF EXISTS delete_vault_objects ON storage.objects;
CREATE POLICY delete_vault_objects ON storage.objects FOR DELETE TO authenticated USING (
  bucket_id = 'qifi-vault' AND
  split_part(name, '/', 1) = 'workspaces' AND
  split_part(name, '/', 2) IN (SELECT workspace_id FROM public.workspace_members WHERE user_id = auth.uid())
);
