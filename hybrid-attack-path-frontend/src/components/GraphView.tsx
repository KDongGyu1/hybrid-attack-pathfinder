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
  PUBLIC: '#9ca3af',
  INTERNAL: '#60a5fa',
  CONFIDENTIAL: '#f59e0b',
  RESTRICTED: '#ef4444',
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
            'font-size': 10,
            'text-valign': 'bottom',
            'text-margin-y': 6,
            'background-color': (ele: NodeSingular) =>
              SENSITIVITY_COLOR[ele.data('sensitivityLevel')] ?? '#6b7280',
            width: 36,
            height: 36,
          },
        },
        {
          selector: 'edge',
          style: {
            label: 'data(relation)',
            'font-size': 8,
            width: 'data(weight)',
            'line-color': '#94a3b8',
            'target-arrow-color': '#94a3b8',
            'target-arrow-shape': 'triangle',
            'curve-style': 'bezier',
          },
        },
      ],
      layout: { name: 'breadthfirst', directed: true, padding: 30 },
    });

    cyRef.current = cy;
    return () => cy.destroy();
  }, [elements]);

  return <div ref={containerRef} className="h-[520px] w-full rounded-lg border border-neutral-200 bg-white" />;
}
