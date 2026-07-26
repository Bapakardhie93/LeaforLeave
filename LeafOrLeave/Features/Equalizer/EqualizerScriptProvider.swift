import WebKit

enum EqualizerScriptProvider {
    static var script: WKUserScript {
        WKUserScript(source: source, injectionTime: .atDocumentStart, forMainFrameOnly: false)
    }

    static let source = #"""
    (() => {
      if (window.__leafEqualizerController) return;

      const frequencies = [32, 64, 125, 250, 500, 1000, 2000, 4000, 8000, 16000];
      const state = {
        context: null,
        chains: new WeakMap(),
        chainList: [],
        enabled: false,
        gains: frequencies.map(() => 0),
        preamp: 0,
        lastError: null
      };

      const mediaElements = () => [...document.querySelectorAll('audio, video')]
        .filter(element => element.readyState >= 1)
        .sort((a, b) =>
          (Number(!b.paused) - Number(!a.paused)) ||
          (Number(!b.muted && b.volume > 0) - Number(!a.muted && a.volume > 0)) ||
          ((b.clientWidth * b.clientHeight) - (a.clientWidth * a.clientHeight))
        );

      const contextForPage = () => {
        if (state.context && state.context.state !== 'closed') return state.context;
        const AudioContextClass = window.AudioContext || window.webkitAudioContext;
        if (!AudioContextClass) throw new Error('Web Audio is not available on this page.');
        state.context = new AudioContextClass({ latencyHint: 'interactive' });
        return state.context;
      };

      const isCrossOriginWithoutCORS = media => {
        try {
          const source = new URL(media.currentSrc || media.src, document.baseURI);
          return !['blob:', 'data:'].includes(source.protocol) &&
            source.origin !== location.origin && !media.crossOrigin;
        } catch (_) {
          return false;
        }
      };

      const updateChain = chain => {
        const now = chain.context.currentTime;
        chain.filters.forEach((filter, index) => {
          filter.gain.setTargetAtTime(state.enabled ? (state.gains[index] || 0) : 0, now, 0.012);
        });
        chain.wet.gain.setTargetAtTime(state.enabled ? 1 : 0, now, 0.008);
        chain.dry.gain.setTargetAtTime(state.enabled ? 0 : 1, now, 0.008);
        const output = state.enabled ? Math.pow(10, state.preamp / 20) : 1;
        chain.output.gain.setTargetAtTime(output, now, 0.012);
      };

      const attach = media => {
        if (state.chains.has(media)) return state.chains.get(media);
        if (media.mediaKeys) throw new DOMException('Protected DRM media cannot be processed.', 'NotSupportedError');
        if (isCrossOriginWithoutCORS(media)) {
          throw new DOMException('This media server does not permit Web Audio processing.', 'SecurityError');
        }

        const context = contextForPage();
        const source = context.createMediaElementSource(media);
        const filters = frequencies.map(frequency => {
          const node = context.createBiquadFilter();
          node.type = 'peaking';
          node.frequency.value = frequency;
          node.Q.value = 1.2;
          return node;
        });
        const wet = context.createGain();
        const dry = context.createGain();
        const output = context.createGain();

        source.connect(filters[0]);
        source.connect(dry);
        filters.forEach((filter, index) => filter.connect(filters[index + 1] || wet));
        wet.connect(output);
        dry.connect(output);
        output.connect(context.destination);

        const chain = { context, source, filters, wet, dry, output, media };
        state.chains.set(media, chain);
        state.chainList.push(chain);
        updateChain(chain);
        return chain;
      };

      const prepareFromUserGesture = () => {
        const candidates = mediaElements();
        if (!candidates.length) return;
        try {
          attach(candidates[0]);
          const context = contextForPage();
          if (context.state === 'suspended') context.resume().catch(() => {});
        } catch (error) {
          state.lastError = error;
        }
      };

      window.__leafEqualizerController = {
        async apply(configuration) {
          state.enabled = Boolean(configuration.enabled);
          state.gains = Array.isArray(configuration.gains)
            ? configuration.gains.slice(0, frequencies.length).map(Number)
            : frequencies.map(() => 0);
          state.preamp = Number(configuration.preamp) || 0;

          const candidates = mediaElements();
          if (!candidates.length) {
            return { status: 'unavailable', message: 'No playable HTML5 audio or video was found on this page.' };
          }

          const media = candidates[0];
          if (media.mediaKeys) {
            return { status: 'protectedMedia', message: 'Protected DRM media cannot be processed by a browser equalizer.' };
          }
          if (isCrossOriginWithoutCORS(media)) {
            return { status: 'blockedBySite', message: 'This media host blocks Web Audio processing. LeafOrLeave left playback untouched.' };
          }

          try {
            attach(media);
            state.chainList.forEach(updateChain);
            const context = contextForPage();
            if (context.state === 'suspended') {
              try { await context.resume(); } catch (_) {}
            }
            if (context.state !== 'running') {
              return {
                status: 'blockedBySite',
                message: 'Click Play once inside the page, then apply the equalizer again.'
              };
            }
            return {
              status: 'available',
              message: state.enabled
                ? 'Equalizer is active on the playing media.'
                : 'Equalizer is bypassed; original audio is playing.'
            };
          } catch (error) {
            const protectedMedia = error.name === 'NotSupportedError';
            return {
              status: protectedMedia ? 'protectedMedia' : 'failed',
              message: `${error.name || 'Error'}: ${error.message || String(error)}`
            };
          }
        }
      };

      document.addEventListener('pointerdown', prepareFromUserGesture, true);
      document.addEventListener('keydown', prepareFromUserGesture, true);
      document.addEventListener('play', event => {
        if (!(event.target instanceof HTMLMediaElement)) return;
        try {
          attach(event.target);
          const context = contextForPage();
          if (context.state === 'suspended') context.resume().catch(() => {});
        } catch (error) {
          state.lastError = error;
        }
      }, true);
    })();
    """#
}
