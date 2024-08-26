package biz.cunning.cunning_document_scanner.fallback

import android.view.View

import android.app.Activity
import android.content.Intent
import android.graphics.Bitmap
import android.net.Uri
import android.os.Bundle
import android.widget.EditText
import android.widget.ImageButton
import androidx.appcompat.app.AppCompatActivity
import biz.cunning.cunning_document_scanner.R
import biz.cunning.cunning_document_scanner.fallback.constants.DefaultSetting
import biz.cunning.cunning_document_scanner.fallback.constants.DocumentScannerExtra
import biz.cunning.cunning_document_scanner.fallback.extensions.move
import biz.cunning.cunning_document_scanner.fallback.extensions.onClick
import biz.cunning.cunning_document_scanner.fallback.extensions.saveToFile
import biz.cunning.cunning_document_scanner.fallback.extensions.screenHeight
import biz.cunning.cunning_document_scanner.fallback.extensions.screenWidth
import biz.cunning.cunning_document_scanner.fallback.models.Document
import biz.cunning.cunning_document_scanner.fallback.models.Point
import biz.cunning.cunning_document_scanner.fallback.models.Quad
import biz.cunning.cunning_document_scanner.fallback.ui.ImageCropView
import biz.cunning.cunning_document_scanner.fallback.utils.CameraUtil
import biz.cunning.cunning_document_scanner.fallback.utils.FileUtil
import biz.cunning.cunning_document_scanner.fallback.utils.ImageUtil
import java.io.File

class DocumentScannerActivity : AppCompatActivity() {

    private var maxNumDocuments = DefaultSetting.MAX_NUM_DOCUMENTS
    private var croppedImageQuality = DefaultSetting.CROPPED_IMAGE_QUALITY
    private val cropperOffsetWhenCornersNotFound = 100.0
    private var document: Document? = null
    private val documents = mutableListOf<Document>()
    private lateinit var imageView: ImageCropView
    private lateinit var ocrResultEditText: EditText // OCR 결과를 표시하고 수정할 수 있는 EditText

    private val cameraUtil = CameraUtil(
        this,
        onPhotoCaptureSuccess = { originalPhotoPath ->

            if (documents.size == maxNumDocuments - 1) {
                val newPhotoButton: ImageButton = findViewById(R.id.new_photo_button)
                newPhotoButton.isClickable = false
                newPhotoButton.visibility = View.INVISIBLE
            }

            val photo: Bitmap? = try {
                ImageUtil().getImageFromFilePath(originalPhotoPath)
            } catch (exception: Exception) {
                finishIntentWithError("Unable to get bitmap: ${exception.localizedMessage}")
                return@CameraUtil
            }

            if (photo == null) {
                finishIntentWithError("Document bitmap is null.")
                return@CameraUtil
            }

            val corners = try {
                val (topLeft, topRight, bottomLeft, bottomRight) = getDocumentCorners(photo)
                Quad(topLeft, topRight, bottomRight, bottomLeft)
            } catch (exception: Exception) {
                finishIntentWithError(
                    "Unable to get document corners: ${exception.message}"
                )
                return@CameraUtil
            }

            document = Document(originalPhotoPath, photo.width, photo.height, corners)

            try {
                imageView.setImagePreviewBounds(photo, screenWidth, screenHeight)
                imageView.setImage(photo)

                val cornersInImagePreviewCoordinates = corners
                    .mapOriginalToPreviewImageCoordinates(
                        imageView.imagePreviewBounds,
                        imageView.imagePreviewBounds.height() / photo.height
                    )
                imageView.setCropper(cornersInImagePreviewCoordinates)
            } catch (exception: Exception) {
                finishIntentWithError(
                    "Unable to get image preview ready: ${exception.message}"
                )
                return@CameraUtil
            }

            // OCR 결과를 받아와 EditText에 설정
            val ocrResult = performOcrOnImage(photo)
            ocrResultEditText.setText(ocrResult)
        },
        onCancelPhoto = {
            if (documents.isEmpty()) {
                onClickCancel()
            }
        }
    )

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_image_crop)

        imageView = findViewById(R.id.image_view)
        ocrResultEditText = findViewById(R.id.ocr_result_edit_text)

        try {
            var userSpecifiedMaxImages: Int? = null
            intent.extras?.get(DocumentScannerExtra.EXTRA_MAX_NUM_DOCUMENTS)?.let {
                if (it.toString().toIntOrNull() == null) {
                    throw Exception(
                        "${DocumentScannerExtra.EXTRA_MAX_NUM_DOCUMENTS} must be a positive number"
                    )
                }
                userSpecifiedMaxImages = it as Int
                maxNumDocuments = userSpecifiedMaxImages as Int
            }

            intent.extras?.get(DocumentScannerExtra.EXTRA_CROPPED_IMAGE_QUALITY)?.let {
                if (it !is Int || it < 0 || it > 100) {
                    throw Exception(
                        "${DocumentScannerExtra.EXTRA_CROPPED_IMAGE_QUALITY} must be a number " +
                                "between 0 and 100"
                    )
                }
                croppedImageQuality = it
            }
        } catch (exception: Exception) {
            finishIntentWithError(
                "Invalid extra: ${exception.message}"
            )
            return
        }

        val newPhotoButton: ImageButton = findViewById(R.id.new_photo_button)
        val completeDocumentScanButton: ImageButton = findViewById(R.id.complete_document_scan_button)
        val retakePhotoButton: ImageButton = findViewById(R.id.retake_photo_button)

        newPhotoButton.onClick { onClickNew() }
        completeDocumentScanButton.onClick { onClickDone() }
        retakePhotoButton.onClick { onClickRetake() }

        try {
            openCamera()
        } catch (exception: Exception) {
            finishIntentWithError("Error opening camera: ${exception.message}")
        }
    }

    private fun getDocumentCorners(photo: Bitmap): List<Point> {
        val cornerPoints: List<Point>? = null
        return cornerPoints ?: listOf(
            Point(0.0, 0.0).move(
                cropperOffsetWhenCornersNotFound,
                cropperOffsetWhenCornersNotFound
            ),
            Point(photo.width.toDouble(), 0.0).move(
                -cropperOffsetWhenCornersNotFound,
                cropperOffsetWhenCornersNotFound
            ),
            Point(0.0, photo.height.toDouble()).move(
                cropperOffsetWhenCornersNotFound,
                -cropperOffsetWhenCornersNotFound
            ),
            Point(photo.width.toDouble(), photo.height.toDouble()).move(
                -cropperOffsetWhenCornersNotFound,
                -cropperOffsetWhenCornersNotFound
            )
        )
    }

    private fun openCamera() {
        document = null
        cameraUtil.openCamera(documents.size)
    }

    private fun addSelectedCornersAndOriginalPhotoPathToDocuments() {
        document?.let { document ->
            val cornersInOriginalImageCoordinates = imageView.corners
                .mapPreviewToOriginalImageCoordinates(
                    imageView.imagePreviewBounds,
                    imageView.imagePreviewBounds.height() / document.originalPhotoHeight
                )
            document.corners = cornersInOriginalImageCoordinates
            documents.add(document)
        }
    }

    private fun onClickNew() {
        addSelectedCornersAndOriginalPhotoPathToDocuments()
        openCamera()
    }

    private fun onClickDone() {
        addSelectedCornersAndOriginalPhotoPathToDocuments()

        // 사용자가 수정한 OCR 결과 가져오기
        val editedOcrResult = ocrResultEditText.text.toString()

        // 수정된 OCR 결과를 저장하거나 전달하는 로직 추가
        saveOcrResult(editedOcrResult)

        cropDocumentAndFinishIntent()
    }

    private fun onClickRetake() {
        document?.let { document -> File(document.originalPhotoFilePath).delete() }
        openCamera()
    }

    private fun onClickCancel() {
        setResult(Activity.RESULT_CANCELED)
        finish()
    }

    private fun cropDocumentAndFinishIntent() {
        val croppedImageResults = arrayListOf<String>()
        for ((pageNumber, document) in documents.withIndex()) {
            val croppedImage: Bitmap? = try {
                ImageUtil().crop(
                    document.originalPhotoFilePath,
                    document.corners
                )
            } catch (exception: Exception) {
                finishIntentWithError("Unable to crop image: ${exception.message}")
                return
            }

            if (croppedImage == null) {
                finishIntentWithError("Result of cropping is null")
                return
            }

            File(document.originalPhotoFilePath).delete()

            try {
                val croppedImageFile = FileUtil().createImageFile(this, pageNumber)
                croppedImage.saveToFile(croppedImageFile, croppedImageQuality)
                croppedImageResults.add(Uri.fromFile(croppedImageFile).toString())
            } catch (exception: Exception) {
                finishIntentWithError(
                    "Unable to save cropped image: ${exception.message}"
                )
            }
        }

        setResult(
            Activity.RESULT_OK,
            Intent().putExtra("croppedImageResults", croppedImageResults)
        )
        finish()
    }

    private fun finishIntentWithError(errorMessage: String) {
        setResult(
            Activity.RESULT_OK,
            Intent().putExtra("error", errorMessage)
        )
        finish()
    }

    private fun performOcrOnImage(photo: Bitmap): String {
        // 여기에서 OCR 처리를 수행하고 결과를 반환
        return "Sample OCR result" // 실제 OCR 결과로 대체
    }

    private fun saveOcrResult(ocrResult: String) {
        // 수정된 OCR 결과를 저장하는 로직을 구현
        val outputFile = File(getExternalFilesDir(null), "ocr_result.txt")
        outputFile.writeText(ocrResult)

        // Intent로 다른 Activity에 전달하는 경우
        val intent = Intent()
        intent.putExtra("OCR_RESULT", ocrResult)
        setResult(Activity.RESULT_OK, intent)
    }
}
