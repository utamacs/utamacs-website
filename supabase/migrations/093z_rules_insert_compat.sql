-- Bridge migration: make rules INSERT forwards-compatible with sprints that
-- omit rule_category, label, or default_value.
-- getRules() only reads rule_code + current_value; the other columns are
-- admin-display only. The trigger fills them from the row's own values so
-- every sprint migration INSERT succeeds regardless of which columns it lists.

CREATE OR REPLACE FUNCTION rules_insert_defaults()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  IF NEW.rule_category IS NULL OR NEW.rule_category = '' THEN
    NEW.rule_category := 'PARAMETER';
  END IF;
  IF NEW.label IS NULL OR NEW.label = '' THEN
    NEW.label := NEW.rule_code;
  END IF;
  IF NEW.default_value IS NULL THEN
    NEW.default_value := NEW.current_value;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS rules_insert_defaults_trig ON rules;
CREATE TRIGGER rules_insert_defaults_trig
  BEFORE INSERT ON rules
  FOR EACH ROW EXECUTE FUNCTION rules_insert_defaults();
