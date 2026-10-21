# package marker (lazy exports)
import importlib as _importlib

_EXPORTS = {'REQUEST_OVERRIDABLE': 'doc_ocr.config', 'Settings': 'doc_ocr.config', 'DocOcrError': 'doc_ocr.errors', 'InvalidDocumentError': 'doc_ocr.errors', 'InvalidPagesError': 'doc_ocr.errors', 'TooManyPagesError': 'doc_ocr.errors', 'UnsupportedFileError': 'doc_ocr.errors', 'OcrPipeline': 'doc_ocr.pipeline', 'OcrResult': 'doc_ocr.schemas', 'PageResult': 'doc_ocr.schemas'}
__all__ = sorted(_EXPORTS)
__version__ = '0.1.0'


def __getattr__(name):
    module = _EXPORTS.get(name)
    if module is None:
        raise AttributeError(name)
    return getattr(_importlib.import_module(module), name)
