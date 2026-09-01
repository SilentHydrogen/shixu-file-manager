export function widgetThemeColor(theme: string, name: string): string {
  if (theme === 'coral') {
    if (name === 'accent_primary') return '#F06F52';
    if (name === 'accent_blue') return '#5D8FAA';
    if (name === 'accent_amber') return '#D4875C';
    if (name === 'header_bg') return '#FFE4DB';
    if (name === 'header_text') return '#7F3428';
    if (name === 'row_accent') return '#F06F52';
    if (name === 'widget_bg') return '#FFFCFBF2';
    if (name === 'widget_tint') return '#FFF1EC';
    if (name === 'widget_tint_secondary') return '#EAF2F5';
    if (name === 'text_primary') return '#302521';
    if (name === 'text_body') return '#766B67';
    if (name === 'text_caption') return '#A69A95';
    if (name === 'divider') return '#E8DCD7';
  }
  if (theme === 'violet') {
    if (name === 'accent_primary') return '#6958D6';
    if (name === 'accent_blue') return '#7386B8';
    if (name === 'accent_amber') return '#C98A72';
    if (name === 'header_bg') return '#E9E6F8';
    if (name === 'header_text') return '#40366F';
    if (name === 'row_accent') return '#6958D6';
    if (name === 'widget_bg') return '#FCFBFFF2';
    if (name === 'widget_tint') return '#F1EFFF';
    if (name === 'widget_tint_secondary') return '#E9EEF8';
    if (name === 'text_primary') return '#27243A';
    if (name === 'text_body') return '#68657A';
    if (name === 'text_caption') return '#9692A8';
    if (name === 'divider') return '#E1DDF0';
  }
  if (name === 'accent_primary') return '#00B887';
  if (name === 'accent_blue') return '#4D93A3';
  if (name === 'accent_amber') return '#D38A62';
  if (name === 'header_bg') return '#DDF5EE';
  if (name === 'header_text') return '#145C4B';
  if (name === 'row_accent') return '#00B887';
  if (name === 'widget_bg') return '#F9FFFCF2';
  if (name === 'widget_tint') return '#E9F8F2';
  if (name === 'widget_tint_secondary') return '#E9F0FF';
  if (name === 'text_primary') return '#18252A';
  if (name === 'text_body') return '#66737A';
  if (name === 'text_caption') return '#98A3A6';
  if (name === 'divider') return '#D9E8E2';
  return '#66737A';
}
