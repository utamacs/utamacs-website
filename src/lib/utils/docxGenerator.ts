import {
  AlignmentType, BorderStyle, Document, Footer, Header, ImageRun, Packer,
  PageNumber, Paragraph, Table, TableCell, TableRow, TextRun, WidthType,
} from 'docx';

export interface DocxTemplate {
  society_name?: string;
  society_tagline?: string;
  society_reg_no?: string;
  society_address_line1?: string;
  society_address_line2?: string;
  society_address_line3?: string;
  footer_website?: string;
  footer_phone?: string;
  footer_email?: string;
  closing_line1?: string;
  closing_line2?: string;
  subsequent_page_header?: string;
  logo_height_px?: number;
  logo_width_px?: number;
  letterhead_committee_members?: Array<{
    name: string;
    designation: string;
    show_in_header?: boolean;
    show_in_signature?: boolean;
    display_order?: number;
  }>;
}

function formatDate(iso: string): string {
  const d = new Date(iso + 'T00:00:00');
  return d.toLocaleDateString('en-IN', { day: 'numeric', month: 'long', year: 'numeric' });
}

export async function generateDocxBuffer(
  template: DocxTemplate,
  fieldValues: Record<string, string | undefined>,
  signatories: Array<{ designation: string }>,
  logoBase64?: string,
): Promise<Buffer> {
  const NAVY = '1a2a6c';
  const GOLD = 'c8a84b';
  const NO_BORDER = { style: BorderStyle.NONE, size: 0, color: 'FFFFFF' };

  const headerMembers = (template.letterhead_committee_members ?? [])
    .filter(m => m.show_in_header !== false)
    .sort((a, b) => (a.display_order ?? 0) - (b.display_order ?? 0));

  function tr(text: string, opts?: Record<string, unknown>): TextRun {
    return new TextRun({ text: String(text ?? ''), font: 'Carlito', size: 22, ...opts } as ConstructorParameters<typeof TextRun>[0]);
  }
  function p(children: TextRun | TextRun[], opts?: Record<string, unknown>): Paragraph {
    return new Paragraph({ children: Array.isArray(children) ? children : [children], ...opts } as ConstructorParameters<typeof Paragraph>[0]);
  }

  const dateStr = fieldValues.date ? formatDate(fieldValues.date) : formatDate(new Date().toISOString().slice(0, 10));

  // Build header: logo+address table when logo available, text-only otherwise
  let headerChildren: (Paragraph | Table)[];
  if (logoBase64) {
    const logoH = template.logo_height_px ?? 100;
    const logoW = (template.logo_width_px ?? 0) > 0 ? template.logo_width_px! : Math.round(logoH * 3.0);
    const addrCells = [
      template.society_address_line1,
      template.society_address_line2,
      template.society_address_line3,
    ].filter(Boolean).map(line =>
      p(tr(line!, { bold: true, color: NAVY, size: 16 }), { spacing: { after: 40 } }));
    const memberCells = headerMembers.map(m =>
      p([tr(m.designation, { bold: true, color: GOLD, size: 16 }), tr('  ' + m.name, { bold: true, color: NAVY, size: 16 })],
        { spacing: { after: 40 } }));

    headerChildren = [
      new Table({
        width: { size: 100, type: WidthType.PERCENTAGE },
        rows: [new TableRow({
          children: [
            new TableCell({
              borders: { top: NO_BORDER, bottom: NO_BORDER, left: NO_BORDER, right: NO_BORDER },
              children: [new Paragraph({
                children: [new ImageRun({
                  data: Buffer.from(logoBase64, 'base64'),
                  transformation: { width: logoW, height: logoH },
                } as ConstructorParameters<typeof ImageRun>[0])],
              })],
            }),
            new TableCell({
              borders: { top: NO_BORDER, bottom: NO_BORDER, left: NO_BORDER, right: NO_BORDER },
              width: { size: 3000, type: WidthType.DXA },
              children: [...addrCells, ...memberCells],
            }),
          ],
        })],
      }),
      p(tr(''), { spacing: { after: 60 }, border: { bottom: { style: BorderStyle.SINGLE, size: 6, color: NAVY, space: 4 } } }),
    ];
  } else {
    headerChildren = [
      p(tr(`${template.society_name ?? 'URBAN TRILLA MACS'}  |  ${template.society_tagline ?? 'COMMUNITY • CARE • MAINTENANCE'}`,
        { bold: true, color: NAVY, size: 24 }), { spacing: { after: 60 } }),
      p(tr(`Reg No: ${template.society_reg_no ?? 'TG/RRD/MACS/2026-15/FOW & M'}  |  ${template.society_address_line1 ?? ''} ${template.society_address_line2 ?? ''} ${template.society_address_line3 ?? ''}`,
        { size: 16, color: '374151' }), { spacing: { after: 60 } }),
      p(headerMembers.map(m => tr(`${m.designation}: ${m.name}   `, { bold: true, size: 16, color: NAVY })),
        { spacing: { after: 60 }, border: { bottom: { style: BorderStyle.SINGLE, size: 6, color: NAVY, space: 4 } } }),
    ];
  }
  const headerParas = headerChildren;

  const footerParas: Paragraph[] = [
    p(tr(`Web: ${template.footer_website ?? 'www.utamacs.org'}    Ph: ${template.footer_phone ?? '+91 7032820247'}    Email: ${template.footer_email ?? 'urbantrillaresidents@gmail.com'}`,
      { size: 16, color: '374151' }),
      { border: { top: { style: BorderStyle.SINGLE, size: 6, color: NAVY, space: 4 } }, spacing: { after: 40 } }),
    p([
      tr('Page ', { size: 14, color: '6b7280' }),
      new TextRun({ children: [PageNumber.CURRENT], font: 'Carlito', size: 14, color: '6b7280' }),
      tr(' of ', { size: 14, color: '6b7280' }),
      new TextRun({ children: [PageNumber.TOTAL_PAGES], font: 'Carlito', size: 14, color: '6b7280' }),
    ], { alignment: AlignmentType.RIGHT }),
  ];

  const bodyContent: (Paragraph | Table)[] = [];

  bodyContent.push(p(tr(dateStr), { spacing: { after: 200 } }));

  if (fieldValues.to?.trim()) {
    bodyContent.push(p(tr('To', { bold: true }), { spacing: { after: 40 } }));
    fieldValues.to.trim().split('\n').forEach(line =>
      bodyContent.push(p(tr(line), { spacing: { after: 40 } })));
    bodyContent.push(p(tr(''), { spacing: { after: 120 } }));
  }

  if (fieldValues.subject?.trim()) {
    bodyContent.push(p([tr('Subject: ', { bold: true }), tr(fieldValues.subject)], { spacing: { after: 200 } }));
  }

  if (fieldValues.tosalutation?.trim()) {
    bodyContent.push(p(tr(`Dear ${fieldValues.tosalutation}`), { spacing: { after: 200 } }));
  }

  (fieldValues.message?.trim() ?? '').split('\n').forEach(line =>
    bodyContent.push(p(tr(line || ' '), { alignment: AlignmentType.JUSTIFIED, spacing: { after: 80 } })));

  bodyContent.push(p(tr(''), { spacing: { after: 200 } }));
  bodyContent.push(p(tr(template.closing_line1 ?? 'Thanking you!'), { spacing: { after: 80 } }));
  bodyContent.push(p(tr(template.closing_line2 ?? 'Yours sincerely'), { spacing: { after: 800 } }));

  if (signatories.length > 0) {
    const colW = Math.floor(9360 / signatories.length);
    bodyContent.push(new Table({
      width: { size: 100, type: WidthType.PERCENTAGE },
      rows: [
        new TableRow({ children: signatories.map(() => new TableCell({
          borders: { top: NO_BORDER, left: NO_BORDER, right: NO_BORDER,
            bottom: { style: BorderStyle.SINGLE, size: 4, color: 'd1d5db' } },
          children: [p(tr(''), { spacing: { before: 500 } })],
          width: { size: colW, type: WidthType.DXA },
        })) }),
        new TableRow({ children: signatories.map(s => new TableCell({
          borders: { top: NO_BORDER, left: NO_BORDER, right: NO_BORDER, bottom: NO_BORDER },
          children: [p(tr(s.designation, { bold: true, color: GOLD, size: 18 }), { spacing: { after: 40 } })],
        })) }),
        new TableRow({ children: signatories.map(() => new TableCell({
          borders: { top: NO_BORDER, left: NO_BORDER, right: NO_BORDER, bottom: NO_BORDER },
          children: [p(tr(template.society_name ?? 'Urban Trilla MACS', { color: NAVY, size: 18 }))],
        })) }),
      ],
    }));
  }

  const doc = new Document({
    sections: [{
      properties: { page: { margin: { top: 2200, bottom: 1100, left: 910, right: 910 } } },
      headers: { default: new Header({ children: headerParas }) },
      footers: { default: new Footer({ children: footerParas }) },
      children: bodyContent,
    }],
  });

  return Packer.toBuffer(doc) as unknown as Promise<Buffer>;
}
