import React from 'react';
import { ChartData } from '../../types';

interface RevenueChartProps {
  data: ChartData;
}

export function RevenueChart({ data }: RevenueChartProps) {
  // Calculate the maximum value for scaling
  const maxValue = Math.max(...data.datasets[0].data);
  const scale = 200 / maxValue; // Scale to fit in 200px height

  return (
    <div className="bg-white rounded-lg shadow-sm p-6">
      <h3 className="text-lg font-semibold text-gray-900 mb-4">Revenue Trends</h3>
      <div className="relative h-[200px]">
        <div className="absolute inset-0">
          {/* Grid lines */}
          <div className="grid grid-cols-1 h-full gap-4">
            {[0, 1, 2, 3, 4].map((i) => (
              <div
                key={i}
                className="border-t border-gray-100 relative"
              >
                <span className="absolute -left-8 -top-2.5 text-xs text-gray-500">
                  ${maxValue * (1 - i/4)}
                </span>
              </div>
            ))}
          </div>
          
          {/* Bars */}
          <div className="absolute inset-0 flex items-end justify-between pt-4">
            {data.datasets[0].data.map((value, index) => (
              <div
                key={index}
                className="group relative flex-1 mx-1"
              >
                <div
                  className="absolute bottom-0 inset-x-1 bg-blue-500 rounded-t transition-all duration-300 group-hover:bg-blue-600"
                  style={{ height: `${value * scale}px` }}
                >
                  {/* Tooltip */}
                  <div className="absolute -top-10 left-1/2 -translate-x-1/2 bg-gray-900 text-white text-xs py-1 px-2 rounded opacity-0 group-hover:opacity-100 transition-opacity">
                    ${value}
                  </div>
                </div>
              </div>
            ))}
          </div>
        </div>
      </div>
      {/* X-axis labels */}
      <div className="flex justify-between mt-4">
        {data.labels.map((label, index) => (
          <div key={index} className="text-xs text-gray-500">
            {label}
          </div>
        ))}
      </div>
    </div>
  );
}