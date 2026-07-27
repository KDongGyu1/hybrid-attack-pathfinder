'use client';

import { useEffect, useRef } from 'react';
import cytoscape, { ElementDefinition, NodeSingular } from 'cytoscape';

export interface GraphElementInput {
  data: Record<string, unknown>;
}

interface GraphViewProps {
  elements: GraphElementInput[];
}

const SENSITIVITY_COLOR: Record<string, string> = {
  PUBLIC: '#64748b',
  INTERNAL: '#38bdf8',
  CONFIDENTIAL: '#f59e0b',
  RESTRICTED: '#f43f5e',
};

export default function GraphView({ elements }: GraphViewProps) {
  const containerRef = useRef<HTMLDivElement>(null);
  const cyRef = useRef<cytoscape.Core | null>(null);

  useEffect(() => {
    if (!containerRef.current) return;

    cyRef.current?.destroy();

    const cy = cytoscape({
      container: containerRef.current,
      elements: elements as unknown as ElementDefinition[], // API 응답을 변환 없이 그대로 주입 (설계 문서 2.7, 6.5)
      style: [
        {
          selector: 'node',
          style: {
            label: 'data(label)',
            color: '#f1f5f9',
            'font-size': 13,
            'font-weight': 600,
            'text-valign': 'bottom',
            'text-margin-y': 8,
            'text-outline-width': 2.5,
            'text-outline-color': '#0b0f19',
            'text-outline-opacity': 0.9,
            'background-color': (ele: NodeSingular) =>
              SENSITIVITY_COLOR[ele.data('sensitivityLevel')] ?? '#475569',
            'border-width': 2,
            'border-color': '#0b0f19',
            'border-opacity': 0.6,
            width: 38,
            height: 38,
          },
        },
        {
          selector: 'edge',
          style: {
            label: 'data(relation)',
            color: '#cbd5e1',
            'font-size': 10,
            'text-background-color': '#0b0f19',
            'text-background-opacity': 0.85,
            'text-background-padding': '3px',
            'text-background-shape': 'roundrectangle',
            width: 1.6,
            'line-color': '#334155',
            'target-arrow-color': '#475569',
            'target-arrow-shape': 'triangle',
            'arrow-scale': 0.8,
            'curve-style': 'bezier',
          },
        },
        {
          selector: 'node:selected',
          style: {
            'border-width': 3,
            'border-color': '#38bdf8',
            'border-opacity': 1,
          },
        },
      ],
      layout: { name: 'breadthfirst', directed: true, padding: 30 },
    });

    cyRef.current = cy;
    return () => cy.destroy();
  }, [elements]);

  return (
    <div
      ref={containerRef}
      className="h-[560px] w-full rounded-xl border border-slate-800 bg-slate-900/60"
    />
  );
}
