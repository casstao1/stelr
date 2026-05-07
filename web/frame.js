export function mountFrame(parent) {
  const frame = document.createElement('div');
  frame.className = 'ios-frame';
  frame.innerHTML = `
    <div class="ios-statusbar">
      <span class="time">9:41</span>
      <span class="right">
        <svg width="18" height="12" viewBox="0 0 18 12"><path fill="currentColor" d="M1 9h2v2H1zM5 7h2v4H5zM9 4h2v7H9zM13 1h2v10h-2z"/></svg>
        <svg width="16" height="12" viewBox="0 0 16 12"><path fill="currentColor" d="M8 3.5c2 0 3.8.7 5.2 1.9l1.4-1.4C12.8 2.4 10.5 1.5 8 1.5S3.2 2.4 1.4 4l1.4 1.4C4.2 4.2 6 3.5 8 3.5zM8 7c1.1 0 2.1.4 2.9 1.1l1.4-1.4C11 5.6 9.5 5 8 5s-3 .6-4.3 1.7l1.4 1.4C5.9 7.4 6.9 7 8 7zM8 10.5l2-2c-.5-.5-1.2-.8-2-.8s-1.5.3-2 .8l2 2z"/></svg>
        <svg width="26" height="12" viewBox="0 0 26 12">
          <rect x="1" y="1" width="22" height="10" rx="2.5" fill="none" stroke="currentColor" stroke-opacity="0.5"/>
          <rect x="3" y="3" width="16" height="6" rx="1" fill="currentColor"/>
          <rect x="24" y="4" width="1.5" height="4" rx="0.5" fill="currentColor" fill-opacity="0.5"/>
        </svg>
      </span>
    </div>
    <div id="screen-root" class="screen"></div>
  `;
  parent.appendChild(frame);
  return frame.querySelector('#screen-root');
}
